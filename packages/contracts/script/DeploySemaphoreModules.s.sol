// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { Script, console } from "forge-std/Script.sol";

import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { ISemaphoreVerifier, Semaphore } from "semaphore/Semaphore.sol";

// Passing SALT parameter to use CREATE2 for deterministic contract address
bytes32 constant SALT = bytes32(0);

contract DeploySemaphoreModules is Script {
    SemaphoreVerifier internal semaphoreVerifier;
    Semaphore internal semaphore;
    SemaphoreValidator internal semaphoreValidator;
    SemaphoreExecutor internal semaphoreExecutor;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        // Deploy Semaphore
        semaphoreVerifier = new SemaphoreVerifier{ salt: SALT }();
        semaphore = new Semaphore{ salt: SALT }(ISemaphoreVerifier(address(semaphoreVerifier)));

        // Deploy the executor
        semaphoreExecutor = new SemaphoreExecutor{ salt: SALT }(semaphore);

        // Deploy  the validator
        semaphoreValidator = new SemaphoreValidator{ salt: SALT }(semaphoreExecutor);

        // Set semaphoreValidator in the executor
        semaphoreExecutor.setSemaphoreValidator(address(semaphoreValidator));

        // solhint-disable no-console
        console.log("Semaphore contract: %s", address(semaphore));
        console.log("SemaphoreExecutor contract: %s", address(semaphoreExecutor));
        console.log("SemaphoreValidator contract: %s", address(semaphoreValidator));
        // solhint-enable no-console

        vm.stopBroadcast();
    }
}
