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

import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore, ISemaphoreVerifier } from "semaphore/Semaphore.sol";

import { Identity, IdentityLib, SimpleContract } from "test/utils/TestUtils.sol";
import { NUM_USERS } from "test/utils/Constants.sol";

struct User {
    uint256 sk;
    address addr;
    Identity identity;
}

abstract contract SharedTestSetup is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreValidator internal semaphoreValidator;
    SemaphoreExecutor internal semaphoreExecutor;
    SimpleContract internal simpleContract;
    User[] internal $users;

    function setUp() public virtual {
        super.init();

        // Deploy Semaphore
        SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
        vm.label(address(semaphoreVerifier), "SemaphoreVerifier");

        Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
        vm.label(address(semaphore), "Semaphore");

        // Create the executor
        semaphoreExecutor = new SemaphoreExecutor(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreExecutor");

        // Create the validator
        semaphoreValidator = new SemaphoreValidator(semaphoreExecutor);
        vm.label(address(semaphoreValidator), "SemaphoreValidator");

        // Set semaphoreValidator in the executor
        semaphoreExecutor.setSemaphoreValidator(address(semaphoreValidator));

        // Create the smart account
        smartAcct = makeAccountInstance("SmartAccount");
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

    modifier deploySimpleContract() {
        simpleContract = new SimpleContract(0);
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
