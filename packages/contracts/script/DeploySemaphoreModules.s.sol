// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { Script, console } from "forge-std/Script.sol";

import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { ISemaphoreVerifier, Semaphore } from "semaphore/Semaphore.sol";
import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { ModuleType, RegistryDeployer } from "modulekit/deployment/registry/RegistryDeployer.sol";

// Passing SALT parameter to use CREATE2 for deterministic contract address
bytes32 constant SALT = bytes32(0);

contract DeploySemaphoreModules is Script, RegistryDeployer {
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

        // Deploy the validator
        semaphoreValidator = new SemaphoreValidator{ salt: SALT }(semaphoreExecutor);

        // Set semaphoreValidator in the executor
        semaphoreExecutor.setSemaphoreValidator(address(semaphoreValidator));

        // Register and mock the attestion - executor
        _registerAndAttest({
            moduleAddr: address(semaphoreExecutor),
            moduleType: MODULE_TYPE_EXECUTOR,
            metadata: bytes("Semaphore Executor v0.1"),
            resolverContext: ""
        });

        // Register and mock the attestion - validator
        _registerAndAttest({
            moduleAddr: address(semaphoreValidator),
            moduleType: MODULE_TYPE_VALIDATOR,
            metadata: bytes("Semaphore Validator v0.1"),
            resolverContext: ""
        });

        // solhint-disable no-console
        console.log("Semaphore contract: %s", address(semaphore));
        console.log("SemaphoreExecutor contract: %s", address(semaphoreExecutor));
        console.log("SemaphoreValidator contract: %s", address(semaphoreValidator));
        // solhint-enable no-console

        vm.stopBroadcast();
    }

    /********
     * Internal function
     *******/
    function _registerAndAttest(address moduleAddr, uint256 moduleType, bytes memory metadata, bytes memory resolverContext) internal {
        registerModule({
            module: moduleAddr,
            metadata: metadata,
            resolverContext: resolverContext
        });

        ModuleType[] memory mts = new ModuleType[](1);
        mts[0] = ModuleType.wrap(moduleType);

        mockAttestToModule({
            module: moduleAddr,
            attestationData: metadata,
            moduleTypes: mts
        });

        require(isModuleAttestedMock(moduleAddr), "module registration and attestation failed");
    }
}
