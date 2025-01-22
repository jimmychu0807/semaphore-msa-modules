// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone module-kit
import { IERC7579Account } from "modulekit/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";

import { ISemaphoreMSAExecutor } from "./interfaces/ISemaphoreMSAExecutor.sol";
import { ISemaphore, ISemaphoreGroups } from "./utils/Semaphore.sol";

import { console } from "forge-std/console.sol";

contract SemaphoreMSAExecutor is ISemaphoreMSAExecutor, ERC7579ExecutorBase {
    /**
     * Events
     */
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);
    event ExecutedTx(address indexed account, address indexed target, uint256 indexed value);

    /**
     * Storage
     */
    ISemaphore public semaphore;

    constructor(ISemaphore _semaphore) {
        semaphore = _semaphore;
    }

    /**
     * Config
     */
    function isInitialized(address account) external view override returns (bool) {
        return true;
    }

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        emit ModuleInitialized(account);
    }

    function onUninstall(bytes calldata data) external override {
        address account = msg.sender;
        emit ModuleUninitialized(account);
    }

    function executeTx(address target, uint256 value, bytes calldata callData) external returns (bytes memory returnData) {
        // retrieve the group ID
        address account = msg.sender;
        // uint8 threshold = thresholds[account];
        // ExtCallCount storage ecc = acctTxCount[account][txHash];

        // if (ecc.count == 0) revert TxHashNotFound(account, txHash);
        // if (ecc.count < threshold) revert ThresholdNotReach(account, threshold, ecc.count);

        // TODO: Review if there a better way to make external contract call given the
        // target address, value, and call data.
        //
        // address payable targetAddr = payable(ecc.targetAddr);
        // (bool success, bytes memory returnData) = targetAddr.call{ value: ecc.value }(ecc.callData);
        // if (!success) revert ExecuteTxFailure(account, targetAddr, ecc.value, ecc.callData);

        console.log("SemaphoreMSAExecutor::executeTx()");
        console.log("from: %s", account);
        console.log("address: %s, value: %s", target, value);
        console.logBytes(callData);

        // Execute the transaction on the owned account
        returnData = IERC7579Account(account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            abi.encodePacked(target, value, callData)
        )[0];

        emit ExecutedTx(account, target, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "SemaphoreMSAExecutor";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.1.0";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
