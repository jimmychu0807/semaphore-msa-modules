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
    VALIDATION_SUCCESS
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// Semaphore
import { ISemaphoreVerifier } from "src/interfaces/Semaphore.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore } from "semaphore/Semaphore.sol";

import { SemaphoreValidator, ERC7579ValidatorBase } from "src/SemaphoreValidator.sol";
import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";

import { LibBytes } from "solady/Milady.sol";
import {
    getEmptyUserOperation,
    getTestUserOpCallData,
    getGroupRmMerkleProof,
    getTestUserOpCallData,
    Identity,
    IdentityLib
} from "test/utils/TestUtils.sol";

import { SharedTestSetup, User } from "test/utils/SharedTestSetup.sol";

import { NUM_USERS, NUM_MEMBERS } from "test/utils/Constants.sol";

contract SemaphoreExecutorTest is SharedTestSetup {
    using ModuleKitHelpers for *;
    using IdentityLib for Identity;

    /**
     * Tests
     */
    function test_onInstall_RevertWithInvalidData() public {
        // Test: InvalidInstallData
        smartAcct.expect4337Revert(SemaphoreExecutor.InvalidInstallData.selector);
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(bytes16(hex"deadbeef"))
        });
    }

    function test_onInstall_Pass() public {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(1), _getMemberCmts(1))
        });

        User memory member = $users[0];

        assertEq(semaphoreExecutor.thresholds(smartAcct.account), 1);
        assertEq(semaphoreExecutor.memberCount(smartAcct.account), 1);
        assertEq(semaphoreExecutor.isInitialized(smartAcct.account), true);

        (bool bExist, uint256 groupId) = semaphoreExecutor.getGroupId(smartAcct.account);
        assertEq(bExist, true);

        assertEq(groupId, 0);
        assertEq(
            semaphoreExecutor.accountHasMember(smartAcct.account, member.identity.commitment()),
            true
        );
    }

    function test_onUninstall_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        // Uninsstall the validator first
        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: ""
        });

        assertEq(semaphoreExecutor.thresholds(smartAcct.account), 0);
        (bool bExist,) = semaphoreExecutor.getGroupId(smartAcct.account);
        assertEq(bExist, false);
        assertEq(semaphoreExecutor.memberCount(smartAcct.account), 0);
        assertEq(semaphoreExecutor.isInitialized(smartAcct.account), false);
    }

    function test_addMembers_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        uint256[] memory newMembers = new uint256[](1);
        Identity newIdentity = $users[1].identity;
        newMembers[0] = newIdentity.commitment();

        // Compose a userOp
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor),
            0,
            abi.encodeWithSelector(SemaphoreExecutor.initiateTx.selector)
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));
        userOp.signature = newIdentity.signHash(userOpHash);

        // Test: The userOp should fail, as $users[1].identity is not a member yet
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreValidator.MemberNotExists.selector,
                smartAcct.account,
                LibBytes.slice(userOp.signature, 0, 64)
            )
        );
        semaphoreValidator.validateUserOp(userOp, userOpHash);

        // Test: addMembers() is successfully executed
        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true, address(semaphoreExecutor));
        emit SemaphoreExecutor.AddedMembers(smartAcct.account, uint8(1));
        semaphoreExecutor.addMembers(newMembers);
        vm.stopPrank();

        assertEq(semaphoreExecutor.memberCount(smartAcct.account), 2);
        assertEq(semaphoreExecutor.accountHasMember(smartAcct.account, newMembers[0]), true);

        // Test: the userOp should pass now
        uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
        assertEq(validationData, VALIDATION_SUCCESS);
    }

    function test_removeMember_Pass() public setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1) {
        uint256[] memory cmts = _getMemberCmts(NUM_MEMBERS);
        Identity rmIdentity = $users[0].identity;
        uint256 rmCmt = rmIdentity.commitment();

        (uint256[] memory merkleProof,) = getGroupRmMerkleProof(cmts, rmCmt);

        // Test: remove member
        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true, address(semaphoreExecutor));
        emit SemaphoreExecutor.RemovedMember(smartAcct.account, rmCmt);
        semaphoreExecutor.removeMember(rmCmt, merkleProof);
        vm.stopPrank();

        assertEq(semaphoreExecutor.memberCount(smartAcct.account), NUM_MEMBERS - 1);
        assertEq(semaphoreExecutor.accountHasMember(smartAcct.account, rmCmt), false);

        // Compose a UserOp
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor),
            0,
            abi.encodeWithSelector(SemaphoreExecutor.initiateTx.selector)
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));
        userOp.signature = rmIdentity.signHash(userOpHash);

        // Test: the userOp should fail and revert
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreValidator.MemberNotExists.selector,
                smartAcct.account,
                LibBytes.slice(userOp.signature, 0, 64)
            )
        );
        semaphoreValidator.validateUserOp(userOp, userOpHash);
    }
}
