// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { PoseidonT3 } from "poseidon-solidity/PoseidonT3.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibString } from "solady/Milady.sol";

library Identity {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getCommitment(bytes memory pubKey) public pure returns (uint256 cmt) {
        (uint256 pkX, uint256 pkY) = abi.decode(pubKey, (uint256, uint256));
        cmt = PoseidonT3.hash([pkX, pkY]);
    }

    function verifySignature(
        bytes32 userOpHash,
        bytes memory signature
    )
        public
        returns (bool)
    {
        (uint256 pkX, uint256 pkY, uint256 s0, uint256 s1, uint256 s2) =
            abi.decode(signature, (uint256, uint256, uint256, uint256, uint256));

        // TODO: implement eddsa-poseidon verifySignature() method in solidity. This part:
        // https://github.com/privacy-scaling-explorations/zk-kit/blob/main/packages/eddsa-poseidon/src/eddsa-poseidon-factory.ts#L127-L158
        // Check if there is existing src to build on:
        //   - circom/contracts: https://github.com/iden3/contracts
        string[] memory inputs = new string[](6);
        inputs[0] = "pnpm";
        inputs[1] = "semaphore-identity";
        inputs[2] = "verify";
        inputs[3] = vm.toString(abi.encodePacked(pkX, pkY));
        inputs[4] = vm.toString(userOpHash);
        inputs[5] = vm.toString(abi.encodePacked(s0, s1, s2));

        bytes memory res = vm.ffi(inputs);
        string memory resStr = string(res);
        return LibString.eq(resStr, "true");
    }
}
