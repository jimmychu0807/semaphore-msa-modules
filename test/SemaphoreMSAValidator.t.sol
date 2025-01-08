// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// forge
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

// Rhinestone Modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { IERC7579Module, IERC7579Validator } from "modulekit/Modules.sol";
import {
    VALIDATION_SUCCESS,
    VALIDATION_FAILED,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ERC4337Helpers } from "modulekit/test/utils/ERC4337Helpers.sol";

// Semaphore
import {
    Semaphore,
    ISemaphore,
    ISemaphoreGroups,
    ISemaphoreVerifier,
    SemaphoreVerifier
} from "../src/utils/Semaphore.sol";

import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "../src/SemaphoreMSAValidator.sol";

import {
    getEmptyUserOperation,
    getEmptySemaphoreProof,
    getTestUserOpCallData,
    Identity,
    IdentityLib
} from "./utils/TestUtils.sol";
import { SimpleContract } from "./utils/SimpleContract.sol";
import { LibSort } from "solady/utils/LibSort.sol";

struct User {
    uint256 sk;
    address addr;
    Identity identity; // user commitment
}

contract SemaphoreValidatorUnitTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreMSAValidator internal semaphoreValidator;
    SimpleContract internal simpleContract;
    User[] internal $users;

    function setUp() public virtual {
        // init() function comes from contract AuxiliaryFactory:
        //   https://github.com/rhinestonewtf/modulekit/blob/main/src/test/Auxiliary.sol
        super.init();

        // Deploy Semaphore
        SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
        vm.label(address(semaphoreVerifier), "SemaphoreVerifier");
        Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
        vm.label(address(semaphore), "Semaphore");

        // Create the validator
        semaphoreValidator = new SemaphoreMSAValidator(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreMSAValidator");

        // Create two users
        (address addr, uint256 sk) = makeAddrAndKey("user1");
        vm.deal(addr, 10 ether);
        $users.push(User({ sk: sk, addr: addr, identity: IdentityLib.genIdentity(1) }));

        (addr, sk) = makeAddrAndKey("user2");
        vm.deal(addr, 10 ether);
        $users.push(User({ sk: sk, addr: addr, identity: IdentityLib.genIdentity(2) }));
    }

    modifier setupSmartAcctOneMember() {
        // Create the smart account and install the validator with one admin
        smartAcct = makeAccountInstance("SemaphoreMSAValidator");
        vm.deal(smartAcct.account, 10 ether);
        uint256[] memory cmts = new uint256[](1);
        cmts[0] = $users[0].identity.commitment();

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: abi.encodePacked(uint8(1), cmts)
        });
        _;
    }

    modifier deploySimpleContract() {
        simpleContract = new SimpleContract(0);
        _;
    }

    function test_onInstallWithOneMember() public setupSmartAcctOneMember {
        assertEq(semaphoreValidator.groupMapping(smartAcct.account), 0);
        assertEq(semaphoreValidator.thresholds(smartAcct.account), 1);
        assertEq(semaphoreValidator.memberCount(smartAcct.account), 1);
        assertEq(semaphoreValidator.isInitialized(smartAcct.account), true);
    }

    function test_onInstallWithInvalidData() public {
        smartAcct = makeAccountInstance("SemaphoreMSAValidator");
        vm.deal(smartAcct.account, 1 ether);

        // Test: InvalidInstallData
        smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidInstallData.selector);
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: abi.encodePacked(bytes16(hex"deadbeef"))
        });
    }

    function test_duplicateInstall() public setupSmartAcctOneMember {
        // The modifier has already installed the validator in smartAcct
        uint256[] memory cmts = new uint256[](1);
        cmts[0] = $users[0].identity.commitment();

        // Test: should revert due to duplicate install
        smartAcct.expect4337Revert();
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: abi.encodePacked(uint8(1), cmts)
        });
    }

    function test_onUninstall() public setupSmartAcctOneMember {
        revert("to be implemented");
    }

    // Test only validateUserOp()
    function test_validateUserOpWithNonMember() public setupSmartAcctOneMember {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            0,
            address(semaphoreValidator),
            abi.encodeCall(
                SemaphoreMSAValidator.initiateTx,
                (address(0), "", getEmptySemaphoreProof(), false)
            )
        );

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = IdentityLib.genIdentity(100);
        userOp.signature = id.signHash(userOpHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreMSAValidator.MemberNotExists.selector, smartAcct.account, id.commitment()
            )
        );

        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOpWithMember() public setupSmartAcctOneMember {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            0,
            address(semaphoreValidator),
            abi.encodeCall(
                SemaphoreMSAValidator.initiateTx,
                (address(0), "", getEmptySemaphoreProof(), false)
            )
        );

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );

        assertEq(validationData, VALIDATION_SUCCESS);
    }

    function test_initiateTokensTransferInvalidSignature() public setupSmartAcctOneMember {
        User storage recipient = $users[1];
        UserOpData memory userOpData = smartAcct.getExecOps({
            target: address(semaphoreValidator),
            value: 1,
            callData: abi.encodeCall(
                SemaphoreMSAValidator.initiateTx,
                (recipient.addr, "", getEmptySemaphoreProof(), false)
            ),
            txValidator: address(semaphoreValidator)
        });

        bytes memory forgedSgn = recipient.identity.signHash(userOpData.userOpHash);
        forgedSgn[forgedSgn.length - 1] = hex"ff";
        forgedSgn[forgedSgn.length - 2] = hex"ff";
        userOpData.userOp.signature = forgedSgn;

        smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSignature.selector);
        userOpData.execUserOps();
    }

    // TODO: fix
    function test_initiateTokensTransferMemberInvalidSemaphoreProof() public setupSmartAcctOneMember {
        User storage member = $users[0];
        User storage recipient = $users[1];
        UserOpData memory userOpData = smartAcct.getExecOps({
            target: address(semaphoreValidator),
            value: 1,
            callData: abi.encodeCall(
                SemaphoreMSAValidator.initiateTx,
                (recipient.addr, "", getEmptySemaphoreProof(), false)
            ),
            txValidator: address(semaphoreValidator)
        });
        userOpData.userOp.signature = member.identity.signHash(userOpData.userOpHash);

        smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSignature.selector);
        userOpData.execUserOps();
    }

    function test_initiateTxOneMemberNonValidatorCall() public
        setupSmartAcctOneMember
        deploySimpleContract
    {
        User storage member = $users[0];
        uint256 testVal = 7;

        UserOpData memory userOpData = smartAcct.getExecOps({
            target: address(simpleContract),
            value: 0,
            callData: abi.encodeCall(SimpleContract.setVal, (testVal)),
            txValidator: address(semaphoreValidator)
        });

        userOpData.userOp.signature = member.identity.signHash(userOpData.userOpHash);

        smartAcct.expect4337Revert(SemaphoreMSAValidator.NonValidatorCallBanned.selector);
        userOpData.execUserOps();
    }

    function test_initiateTxOneMemberAllowedSelectorInvalidSemaphoreProof() public
        setupSmartAcctOneMember
        deploySimpleContract
    {
        User storage member = $users[0];
        uint256 testVal = 7;

        bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
        UserOpData memory userOpData = smartAcct.getExecOps({
            target: address(semaphoreValidator),
            value: 0,
            callData: abi.encodeCall(
                SemaphoreMSAValidator.initiateTx,
                (address(simpleContract), txCallData, getEmptySemaphoreProof(), false)
            ),
            txValidator: address(semaphoreValidator)
        });
        userOpData.userOp.signature = member.identity.signHash(userOpData.userOpHash);

        smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSemaphoreProof.selector);
        userOpData.execUserOps();
    }
}
