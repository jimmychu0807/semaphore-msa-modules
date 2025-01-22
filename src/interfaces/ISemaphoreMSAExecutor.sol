// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { IERC7579Executor } from "modulekit/Modules.sol";

interface ISemaphoreMSAExecutor is IERC7579Executor {
    function executeTx(address target, uint256 value, bytes calldata callData)
        external
        returns (bytes memory returnData);
}
