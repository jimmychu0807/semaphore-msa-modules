// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { PoseidonT3 } from "poseidon-solidity/PoseidonT3.sol";
import { PoseidonT6 } from "poseidon-solidity/PoseidonT6.sol";
import { CurveBabyJubJub } from "src/utils/CurveBabyJubJub.sol";
import { console } from "forge-std/console.sol";

library Identity {
    uint256 internal constant base8x = CurveBabyJubJub.Base8x;
    uint256 internal constant base8y = CurveBabyJubJub.Base8y;

    function getCommitment(bytes memory pubKey) public pure returns (uint256 cmt) {
        (uint256 pkX, uint256 pkY) = abi.decode(pubKey, (uint256, uint256));
        cmt = PoseidonT3.hash([pkX, pkY]);
    }

    function verifySignature(bytes32 message, bytes memory signature) public view returns (bool) {
        // Implement eddsa-poseidon verifySignature() method in solidity.
        // https://github.com/privacy-scaling-explorations/zk-kit/blob/388f72b7a029a14bf5c20861d5f54bdaa98b3ac7/packages/eddsa-poseidon/src/eddsa-poseidon-factory.ts#L127-L158
        (uint256 pkX, uint256 pkY, uint256 s0, uint256 s1, uint256 s2) =
            abi.decode(signature, (uint256, uint256, uint256, uint256, uint256));

        uint256 hm = PoseidonT6.hash([s0, s1, pkX, pkY, uint256(message)]);

        (uint256 pLeftx, uint256 pLefty) = CurveBabyJubJub.pointMul(base8x, base8y, s2);

        (uint256 pRightx, uint256 pRighty) =
            CurveBabyJubJub.pointMul(pkX, pkY, mulmod(hm, 8, CurveBabyJubJub.CURVE_ORDER));
        (uint256 pSumx, uint256 pSumy) = CurveBabyJubJub.pointAdd(s0, s1, pRightx, pRighty);

        return (pLeftx == pSumx && pLefty == pSumy);
    }
}
