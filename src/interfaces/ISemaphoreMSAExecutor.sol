// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { IERC7579Executor } from "modulekit/Modules.sol";
import { ISemaphore } from "src/interfaces/Semaphore.sol";

interface ISemaphoreMSAExecutor is IERC7579Executor {
    function name() external pure returns (string memory);
    function getGroupId(address account) external view returns (bool, uint256);
    function accountHasMember(address account, uint256 cmt) external view returns (bool);

    function initiateTx(
        address targetAddr,
        bytes calldata txCallData,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        payable
        returns (bytes32 txHash);

    function signTx(
        bytes32 txHash,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external;

    function executeTx(bytes32 txHash) external returns (bytes memory);
}
