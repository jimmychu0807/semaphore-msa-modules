// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { PoseidonT2 } from "poseidon-solidity/PoseidonT2.sol";
import { FFIUtils } from "./FFIUtils.sol";
import { console } from "forge-std/console.sol";

library Identity {
    function generateCommitment(bytes memory pubKey) public pure returns (uint256 cmt) {
        // Although pubKey is actually two bigints, (pubKeyX, pubKey Y).
        // The commitment is generated with only the first uint256 (32 bytes).
        (uint256 pubKeyX) = abi.decode(pubKey, (uint256));
        cmt = PoseidonT2.hash([pubKeyX]);
    }

    function verifySignature(
        bytes memory pubKey,
        bytes32 callData,
        bytes[96] memory signature
    )
        public
        // pure
        returns (bool)
    {
        // TODO: implement eddsa-poseidon verifySignature() method in solidity. This part:
        // https://github.com/privacy-scaling-explorations/zk-kit/blob/main/packages/eddsa-poseidon/src/eddsa-poseidon-factory.ts#L127-L158
        // Check if there is existing src to build on:
        //   - circom/contracts: https://github.com/iden3/contracts

        string memory res = FFIUtils.ls();
        console.log("res: %s", res);

        return true;
    }
}
