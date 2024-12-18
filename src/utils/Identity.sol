// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { PoseidonT2 } from "poseidon-solidity/PoseidonT2.sol";

library Identity {
    function generateCommitment(bytes memory pubKey) public pure returns (uint256 cmt) {
        // Although pubKey is actually two bigints, (pubKeyX, pubKey Y).
        // The commitment is generated with only the first uint256 (32 bytes).
        (uint256 pubKeyX) = abi.decode(pubKey, (uint256));
        cmt = PoseidonT2.hash([pubKeyX]);
    }

    function verifySignature(
        bytes memory pubKey,
        bytes memory callData,
        bytes memory signature)
    public pure returns (bool) {
        return false;
    }
}
