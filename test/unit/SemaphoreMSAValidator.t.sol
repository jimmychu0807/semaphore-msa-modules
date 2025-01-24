// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// forge-std
// import { console } from "forge-std/console.sol";

// Rhinestone Modulekit
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";

import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "src/SemaphoreMSAValidator.sol";

import {
    getEmptyUserOperation,
    getTestUserOpCallData,
    Identity,
    IdentityLib
} from "test/utils/TestUtils.sol";
import { SharedTestSetup } from "test/utils/SharedTestSetup.sol";

contract SemaphoreMSAValidatorTest is SharedTestSetup {
    using ModuleKitHelpers for *;
    using IdentityLib for Identity;

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
