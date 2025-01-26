// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { IERC7579Validator } from "modulekit/Modules.sol";

interface ISemaphoreValidator is IERC7579Validator {
    function name() external pure returns (string memory);
}
