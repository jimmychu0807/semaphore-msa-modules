// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { Script, console } from "forge-std/Script.sol";

import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { ISemaphoreVerifier, Semaphore } from "semaphore/Semaphore.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { ModuleType, RegistryDeployer } from "modulekit/deployment/registry/RegistryDeployer.sol";

/* solhint-disable no-console */

// Passing SALT parameter to use CREATE2 for deterministic contract address
bytes32 constant SALT = bytes32(hex"01");
bool constant REGISTER_MODULE = true;
bool constant ATTEST_MODULE = true;

contract DeploySemaphoreModules is Script, RegistryDeployer {
    SemaphoreVerifier internal semaphoreVerifier;
    Semaphore internal semaphore;
    SemaphoreValidator internal semaphoreValidator;
    SemaphoreExecutor internal semaphoreExecutor;

    function setUp() public { }

    function run() public {
        vm.startBroadcast();

        address semaphoreAddress = vm.envOr("SEMAPHORE_ADDRESS", address(0));
        if (semaphoreAddress == address(0)) {
            // Deploy Semaphore
            console.log("Deploying Semaphore and related contracts...");
            semaphoreVerifier = new SemaphoreVerifier{ salt: SALT }();
            semaphore = new Semaphore{ salt: SALT }(ISemaphoreVerifier(address(semaphoreVerifier)));
        } else {
            semaphore = Semaphore(semaphoreAddress);
        }

        address executorAddress = vm.envOr("SEMAPHORE_EXECUTOR_ADDRESS", address(0));
        if (executorAddress == address(0)) {
            // Deploy the executor
            console.log("Deploying Semaphore Executor...");
            semaphoreExecutor = new SemaphoreExecutor{ salt: SALT }(semaphore);
        } else {
            semaphoreExecutor = SemaphoreExecutor(executorAddress);
        }
        // Register and mock the attestion - executor
        _registerAndAttest({
            bRegister: REGISTER_MODULE,
            bAttest: ATTEST_MODULE,
            moduleAddr: address(semaphoreExecutor),
            moduleType: MODULE_TYPE_EXECUTOR,
            metadata: bytes("Semaphore Executor v0.1"),
            resolverContext: ""
        });

        address validatorAddress = vm.envOr("SEMAPHORE_VALIDATOR_ADDRESS", address(0));
        if (validatorAddress == address(0)) {
            // Deploy the validator
            console.log("Deploying Semaphore Validator...");
            semaphoreValidator = new SemaphoreValidator{ salt: SALT }(semaphoreExecutor);
            semaphoreExecutor.setSemaphoreValidator(address(semaphoreValidator));
        } else {
            semaphoreValidator = SemaphoreValidator(validatorAddress);
        }
        // Register and mock the attestion - validator
        _registerAndAttest({
            bRegister: REGISTER_MODULE,
            bAttest: ATTEST_MODULE,
            moduleAddr: address(semaphoreValidator),
            moduleType: MODULE_TYPE_VALIDATOR,
            metadata: bytes("Semaphore Validator v0.1"),
            resolverContext: ""
        });

        console.log("Semaphore contract: %s", address(semaphore));
        console.log("SemaphoreExecutor contract: %s", address(semaphoreExecutor));
        console.log("SemaphoreValidator contract: %s", address(semaphoreValidator));

        vm.stopBroadcast();
    }

    /**
     *
     * Internal function
     *
     */
    function _registerAndAttest(
        bool bRegister,
        bool bAttest,
        address moduleAddr,
        uint256 moduleType,
        bytes memory metadata,
        bytes memory resolverContext
    )
        internal
    {
        if (bRegister) {
            console.log("Registering module: %s", moduleAddr);
            registerModule({
                module: moduleAddr,
                metadata: metadata,
                resolverContext: resolverContext
            });
        }

        if (bAttest && !isModuleAttestedMock(moduleAddr)) {
            console.log("Attesting module: %s of type: %s", moduleAddr, moduleType);
            ModuleType[] memory mts = new ModuleType[](1);
            mts[0] = ModuleType.wrap(moduleType);

            mockAttestToModule({ module: moduleAddr, attestationData: metadata, moduleTypes: mts });
            // forgefmt: disable-next-item
            require(isModuleAttestedMock(moduleAddr), "module reg/attest failed");
        }
    }
}
