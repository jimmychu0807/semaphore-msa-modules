// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// forge-std
import { Test } from "forge-std/Test.sol";

// Rhinestone Modulekit
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { LibSort, LibString } from "solady/Milady.sol";

import { SemaphoreMSAExecutor } from "src/SemaphoreMSAExecutor.sol";
import { SemaphoreMSAValidator } from "src/SemaphoreMSAValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore, ISemaphoreVerifier } from "semaphore/Semaphore.sol";

import { Identity, IdentityLib } from "test/utils/TestUtils.sol";
import { NUM_USERS } from "test/utils/Constants.sol";

struct User {
    uint256 sk;
    address addr;
    Identity identity; // user commitment
}

abstract contract SharedTestSetup is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreMSAValidator internal semaphoreValidator;
    SemaphoreMSAExecutor internal semaphoreExecutor;
    User[] internal $users;

    function setUp() public virtual {
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
}
