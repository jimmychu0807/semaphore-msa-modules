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

import { SemaphoreValidator, ERC7579ValidatorBase } from "src/SemaphoreValidator.sol";
import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";

import { LibSort, LibString } from "solady/Milady.sol";
import {
    getEmptyUserOperation,
    getTestUserOpCallData,
    Identity,
    IdentityLib
} from "test/utils/TestUtils.sol";

import { SharedTestSetup } from "test/utils/SharedTestSetup.sol";

import { NUM_USERS } from "test/utils/Constants.sol";

contract SemaphoreExecutorTest is SharedTestSetup {
    using ModuleKitHelpers for *;
    using IdentityLib for Identity;

    /**
     * Tests
     */

}
