// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { IERC7579Executor } from "modulekit/Modules.sol";
import { ISemaphore } from "src/interfaces/Semaphore.sol";

interface ISemaphoreExecutor is IERC7579Executor {
    function name() external pure returns (string memory);
    function getGroupId(address account) external view returns (bool, uint256);
    function groupMapping(address account) external view returns (uint256);
    function accountHasMember(address account, uint256 cmt) external view returns (bool);

    function initiateTx(
        address target,
        uint256 value,
        bytes calldata callData,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        returns (bytes32 txHash);

    function signTx(
        bytes32 txHash,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external;

    function executeTx(bytes32 txHash) external returns (bytes memory);
}
