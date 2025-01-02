// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { LibBytes } from "solady/utils/LibBytes.sol";

library ValidatorLibBytes {
    uint8 internal constant CMT_BYTELEN = 32;

    function convertToCmts(bytes calldata cmtBytes) public pure returns (uint256[] memory cmts) {
        uint256 cmtNum = cmtBytes.length / CMT_BYTELEN;

        cmts = new uint256[](cmtNum);
        for (uint256 i = 0; i < cmtNum; i++) {
            bytes memory oneCmtByte =
                LibBytes.slice(cmtBytes, i * CMT_BYTELEN, (i + 1) * CMT_BYTELEN);
            cmts[i] = abi.decode(oneCmtByte, (uint256));
        }
    }
}
