// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// forge-std
import { Test } from "forge-std/Test.sol";
// import { console } from "forge-std/console.sol";

// Rhinestone Modulekit
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";

import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// Semaphore
import { ISemaphoreVerifier } from "src/interfaces/Semaphore.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore } from "semaphore/Semaphore.sol";

import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "src/SemaphoreMSAValidator.sol";
import { SemaphoreMSAExecutor } from "src/SemaphoreMSAExecutor.sol";

import { LibSort, LibString } from "solady/Milady.sol";
import {
    getEmptyUserOperation,
    getTestUserOpCallData,
    Identity,
    IdentityLib
} from "test/utils/TestUtils.sol";
import { NUM_USERS } from "test/utils/Constants.sol";

struct User {
    uint256 sk;
    address addr;
    Identity identity; // user commitment
}

contract SemaphoreMSAValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreMSAValidator internal semaphoreValidator;
    SemaphoreMSAExecutor internal semaphoreExecutor;
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

        // Create the executor
        semaphoreExecutor = new SemaphoreMSAExecutor(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreMSAExecutor");

        // Create the validator
        semaphoreValidator = new SemaphoreMSAValidator(semaphoreExecutor);
        vm.label(address(semaphoreValidator), "SemaphoreMSAValidator");

        // Create the smart account
        smartAcct = makeAccountInstance("SemaphoreMSAValidator");
        vm.deal(smartAcct.account, 10 ether);
        vm.label(smartAcct.account, "SmartAccount");

        // Create a few users
        for (uint256 i = 0; i < NUM_USERS; ++i) {
            string memory nickname = string.concat("user", LibString.toString(i + 1));
            (address addr, uint256 sk) = makeAddrAndKey(nickname);
            vm.deal(addr, 5 ether);
            vm.label(addr, nickname);
            $users.push(User({ sk: sk, addr: addr, identity: IdentityLib.genIdentity(i + 1) }));
        }
    }

    /**
     * Modifiers
     */
    modifier setupSmartAcctWithMembersThreshold(uint8 numMembers, uint8 threshold) {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(threshold), _getMemberCmts(numMembers))
        });

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        _;
    }

    /**
     * Internal helper funcitons
     */
    function _getMemberCmts(uint8 num) internal returns (uint256[] memory cmts) {
        cmts = new uint256[](num);
        for (uint8 i = 0; i < num; ++i) {
            cmts[i] = $users[i].identity.commitment();
        }
        cmts.insertionSort();
    }

    /**
     * Tests
     */
    function test_onInstall_NoExecutorShouldRevert() public {
        // Expecting the next call to fail with SemaphoreMSAExecutorNotInitialized error
        smartAcct.expect4337Revert(
            abi.encodeWithSelector(
                SemaphoreMSAValidator.SemaphoreMSAExecutorNotInitialized.selector, smartAcct.account
            )
        );

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });
    }

    function test_onInstall_Pass() public {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(1), _getMemberCmts(1))
        });

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        assertEq(semaphoreValidator.acctInstalled(smartAcct.account), true, "test_onInstall_Pass");
    }

    function test_onInstall_DuplicateInstallShouldRevert() public {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(1), _getMemberCmts(1))
        });

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        smartAcct.expect4337Revert();
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });
    }

    function test_onUninstall_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        assertEq(semaphoreValidator.acctInstalled(smartAcct.account), false);
    }

    function test_onUninstall_DuplicateUninstallShouldRevert()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        smartAcct.expect4337Revert();
        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });
    }

    function test_validateUserOp_NoSemaphoreModuleInstalled() public {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(address(semaphoreExecutor), 0, "");
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        // Test error is thrown
        // forgefmt: disable-next-item
        vm.expectRevert(abi.encodeWithSelector(
            SemaphoreMSAValidator.NoSemaphoreModuleInstalled.selector, smartAcct.account
        ));
        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOp_InvalidSignature()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(address(semaphoreExecutor), 0, "");
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        // Forge a signature
        bytes memory forgedSig = hex"ffff";
        userOp.signature = forgedSig;

        // Test error is thrown
        // forgefmt: disable-next-item
        vm.expectRevert(abi.encodeWithSelector(
            SemaphoreMSAValidator.InvalidSignature.selector, smartAcct.account, forgedSig
        ));
        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOp_MemberNotExists()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(address(semaphoreExecutor), 0, "");
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[1].identity;
        userOp.signature = id.signHash(userOpHash);
        (uint256 pkX, uint256 pkY) = abi.decode(userOp.signature, (uint256, uint256));
        bytes memory pk = abi.encodePacked(pkX, pkY);

        // Test error is thrown
        // forgefmt: disable-next-item
        vm.expectRevert(abi.encodeWithSelector(
            SemaphoreMSAValidator.MemberNotExists.selector, smartAcct.account, pk
        ));
        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOp_InvalidTargetCallData()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(address(semaphoreValidator), 0, "");
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        // Test error is thrown
        vm.expectPartialRevert(SemaphoreMSAValidator.InvalidTargetCallData.selector);
        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOp_InvalidTargetAddress()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreValidator), 0, abi.encodeCall(semaphoreValidator.name, ())
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        // Test error is thrown
        // forgefmt: disable-next-item
        vm.expectRevert(abi.encodeWithSelector(
            SemaphoreMSAValidator.InvalidTargetAddress.selector,
            smartAcct.account,
            address(semaphoreValidator)
        ));
        ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
    }

    function test_validateUserOp_InvalidFuncSel() public setupSmartAcctWithMembersThreshold(1, 1) {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor), 0, abi.encodeCall(semaphoreExecutor.name, ())
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        uint256 res = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );

        assertEq(res, VALIDATION_FAILED, "test_validateUserOp_InvalidFuncSel");
    }

    function test_validateUserOp_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor), 0, abi.encodeCall(semaphoreExecutor.executeTx, (""))
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = $users[0].identity;
        userOp.signature = id.signHash(userOpHash);

        uint256 res = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );

        assertEq(res, VALIDATION_SUCCESS, "test_validateUserOp_Pass");
    }
}
