// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// forge-std
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

// Rhinestone Modulekit
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";

import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// Semaphore
import { ISemaphoreVerifier } from "src/interfaces/Semaphore.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore } from "semaphore/Semaphore.sol";

import { SemaphoreValidator, ERC7579ValidatorBase } from "src/SemaphoreValidator.sol";
import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";

import { LibSort, LibString } from "solady/Milady.sol";
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
}
