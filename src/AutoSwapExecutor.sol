// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { IERC7579Account, Execution } from "modulekit/Accounts.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { UniswapV3Integration } from "modulekit/Integrations.sol";

contract AutoSwapExecutor is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidExecution();

    event ExecutionTriggered(address indexed smartAccount, uint256 indexed jobId);

    struct ExecutionConfig {
        uint48 executeInterval;
        uint32 numberOfExecutions;
        uint32 numberOfExecutionsCompleted;
        uint48 startDate;
        uint48 lastExecutionTime;
        bytes executionData;
    }

    mapping(address smartAccount => mapping(uint64 jobId => ExecutionConfig)) internal _executionLog;
    mapping(address smartAccount => uint64 jobCount) internal _accountJobCount;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        (
            uint48 executeInterval,
            uint32 numberOfExecutions,
            uint48 startDate,
            bytes memory executionData
        ) = abi.decode(data, (uint48, uint32, uint48, bytes));
        _createExecution(executeInterval, numberOfExecutions, startDate, executionData);
    }
    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */

    function onUninstall(bytes calldata data) external override {
        uint64 count = _accountJobCount[msg.sender];
        for (uint64 i = 1; i <= count; i++) {
            delete _executionLog[msg.sender][i];
        }
        _accountJobCount[msg.sender] = 0;
        data;
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return _accountJobCount[smartAccount] > 0;
    }

    function addOrder(
        uint48 executeInterval,
        uint32 numberOfExecutions,
        uint48 startDate,
        bytes memory executionData
    )
        external
    {
        _createExecution(executeInterval, numberOfExecutions, startDate, executionData);
    }

    function removeOrder(uint64 orderId) external {
        delete _executionLog[msg.sender][orderId];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * ERC-7579 does not define any specific interface for executors, so the
     * executor can implement any logic that is required for the specific usecase.
     */

    /**
     * Execute the given data
     * @dev This is an example function that can be used to execute arbitrary data
     * @dev This function is not part of the ERC-7579 standard
     *
     * @param jobId Job ID man
     */
    function executeOrder(uint64 jobId) external canExecute(jobId) {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];

        (address tokenIn, address tokenOut, uint256 amountIn, uint160 sqrtPriceLimitX96) =
            abi.decode(executionConfig.executionData, (address, address, uint256, uint160));

        Execution[] memory executions = UniswapV3Integration.approveAndSwap({
            smartAccount: msg.sender,
            tokenIn: IERC20(tokenIn),
            tokenOut: IERC20(tokenOut),
            amountIn: amountIn,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        executionConfig.lastExecutionTime = uint48(block.timestamp);
        executionConfig.numberOfExecutionsCompleted += 1;

        IERC7579Account(msg.sender).executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)
        );

        emit ExecutionTriggered(msg.sender, jobId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _createExecution(
        uint48 executeInterval,
        uint32 numberOfExecutions,
        uint48 startDate,
        bytes memory executionData
    )
        internal
    {
        uint64 jobId = _accountJobCount[msg.sender]++;

        _executionLog[msg.sender][jobId] = ExecutionConfig({
            numberOfExecutionsCompleted: 0,
            lastExecutionTime: 0,
            executeInterval: executeInterval,
            numberOfExecutions: numberOfExecutions,
            startDate: startDate,
            executionData: executionData
        });
    }

    modifier canExecute(uint64 jobId) {
        _isExecutionValid(jobId);
        _;
    }

    function _isExecutionValid(uint64 jobId) internal view {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];

        if (executionConfig.startDate > block.timestamp) {
            revert InvalidExecution();
        }

        if (executionConfig.numberOfExecutionsCompleted >= executionConfig.numberOfExecutions) {
            revert InvalidExecution();
        }

        if (
            executionConfig.lastExecutionTime + executionConfig.executeInterval < block.timestamp
                && executionConfig.lastExecutionTime > executionConfig.startDate
        ) {
            revert InvalidExecution();
        }
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
        return "AutoSwapExecutor";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
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
