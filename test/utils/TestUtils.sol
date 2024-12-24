// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Vm } from "forge-std/Vm.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ISemaphore } from "../../src/utils/Semaphore.sol";
import { console } from "forge-std/console.sol";
import { LibString } from "solady/Milady.sol";

struct ValidationData {
    address aggregator;
    uint48 validAfter;
    uint48 validUntil;
}

function getEmptyUserOperation() pure returns (PackedUserOperation memory) {
    return PackedUserOperation({
        sender: address(0),
        nonce: 0,
        initCode: "",
        callData: "",
        accountGasLimits: bytes23(abi.encodePacked(uint128(0), uint128(0))),
        preVerificationGas: 0,
        gasFees: bytes32(abi.encodePacked(uint128(0), uint128(0))),
        paymasterAndData: "",
        signature: ""
    });
}

function getEmptySemaphoreProof() pure returns (ISemaphore.SemaphoreProof memory proof) {
    proof = ISemaphore.SemaphoreProof({
        merkleTreeDepth: 0,
        merkleTreeRoot: 0,
        nullifier: 0,
        message: 0,
        scope: 0,
        points: [uint256(0), 0, 0, 0, 0, 0, 0, 0]
    });
}

type Identity is bytes32;

library IdentityLib {
    function genIdentity(uint256 seed) public view returns (Identity) {
        return Identity.wrap(keccak256(abi.encodePacked(seed, address(this))));
    }

    function publicKey(Identity self, Vm vm) internal returns (uint256 pubX, uint256 pubY) {
        string[] memory cmd = new string[](4);
        cmd[0] = "pnpm";
        cmd[1] = "semaphore-identity";
        cmd[2] = "get-public-key";
        cmd[3] = vm.toString(Identity.unwrap(self));

        bytes memory outBytes = vm.ffi(cmd);
        string memory outStr = string(outBytes);
        string[] memory pubs = LibString.split(outStr, " ");

        pubX = vm.parseUint(pubs[0]);
        pubY = vm.parseUint(pubs[1]);
    }

    function signHash(Identity self, bytes32 hash, Vm vm)
        public
        returns (bytes memory signature)
    {
        (uint256 pubX, uint256 pubY) = IdentityLib.publicKey(self, vm);

        // abi.encode(pubX, pubY, id.signHash());

        // TODO: implement Eddsa poseidon signature. This part:
        // https://github.com/privacy-scaling-explorations/zk-kit/blob/main/packages/eddsa-poseidon/src/eddsa-poseidon-factory.ts#L93-L118
    }
}
