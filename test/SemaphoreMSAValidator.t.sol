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
    Identity,
    IdentityLib
} from "./utils/TestUtils.sol";
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

    modifier setupSmartAcctOneUser() {
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

    function test_onInstallWithOneUser() public setupSmartAcctOneUser {
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

    function test_duplicateInstall() public setupSmartAcctOneUser {
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

    function test_onUninstall() public setupSmartAcctOneUser {
        revert("to be implemented");
    }

    function test_validateUserOpWithNonMember() public setupSmartAcctOneUser {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData =
            abi.encodeCall(SemaphoreMSAValidator.initiateTx, ("", getEmptySemaphoreProof(), false));

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

    function test_validateUserOpWithMember() public setupSmartAcctOneUser {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData =
            abi.encodeCall(SemaphoreMSAValidator.initiateTx, ("", getEmptySemaphoreProof(), false));

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );

        assertEq(validationData, VALIDATION_SUCCESS);
    }

    function test_initiateNativeTransferOneUserInvalidSignature() public setupSmartAcctOneUser {
        User storage recipient = $users[1];
        UserOpData memory userOpData = smartAcct.getExecOps({
            target: recipient.addr,
            value: 1,
            callData: "",
            txValidator: address(semaphoreValidator)
        });

        bytes memory forgedSgn = recipient.identity.signHash(userOpData.userOpHash);
        forgedSgn[forgedSgn.length - 1] = hex"ff";
        forgedSgn[forgedSgn.length - 2] = hex"ff";
        userOpData.userOp.signature = forgedSgn;

        // TODO: checking with Konrad Rhinestone on this
        smartAcct.expect4337Revert(/* SemaphoreMSAValidator.InvalidSignature.selector */);
        userOpData.execUserOps();
    }

    function test_initiateNativeTransferOneUserNonMember() public setupSmartAcctOneUser {
        User storage recipient = $users[1];
        UserOpData memory userOpData = smartAcct.getExecOps({
            target: recipient.addr,
            value: 1,
            callData: "",
            txValidator: address(semaphoreValidator)
        });

        userOpData.userOp.signature = recipient.identity.signHash(userOpData.userOpHash);

        // TODO: checking with Konrad Rhinestone on this
        smartAcct.expect4337Revert(/* SemaphoreMSAValidator.MemberNotExists.selector */);
        userOpData.execUserOps();
    }

    function test_initiateNativeTransferOneUserMember() public setupSmartAcctOneUser {
        revert("to be implemented");
    }

    function test_initiateTxExecuteOneUser() public setupSmartAcctOneUser {
        revert("to be implemented");
    }
}
