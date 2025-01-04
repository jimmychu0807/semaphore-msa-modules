// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Vm } from "forge-std/Vm.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ISemaphore } from "../../src/utils/Semaphore.sol";
// import { console } from "forge-std/console.sol";
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
    // https://github.com/foundry-rs/forge-std/blob/master/src/Base.sol#L9
    address internal constant VM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    Vm internal constant vm = Vm(VM_ADDRESS);

    function genIdentity(uint256 seed) public view returns (Identity) {
        return Identity.wrap(keccak256(abi.encodePacked(seed, address(this))));
    }

    function publicKey(Identity self) public returns (uint256[2] memory) {
        return IdentityLib._publicKey(self);
    }

    function commitment(Identity self) public returns (uint256 cmt) {
        // This is using the identity-cli javascript call, instead of identity
        string[] memory cmd = new string[](4);
        cmd[0] = "pnpm";
        cmd[1] = "semaphore-identity";
        cmd[2] = "get-commitment";
        cmd[3] = vm.toString(Identity.unwrap(self));

        bytes memory res = vm.ffi(cmd);
        cmt = abi.decode(res, (uint256));
    }

    // The return value is a 32 + 32 + 96 bytes array
    function signHash(Identity self, bytes32 hash) public returns (bytes memory signature) {
        uint256[2] memory pub = IdentityLib._publicKey(self);
        bytes memory hashSig = IdentityLib._signHash(self, hash);
        return abi.encodePacked(pub, hashSig);
    }

    function _publicKey(Identity self) internal returns (uint256[2] memory pubUint) {
        string[] memory cmd = new string[](4);
        cmd[0] = "pnpm";
        cmd[1] = "semaphore-identity";
        cmd[2] = "get-public-key";
        cmd[3] = vm.toString(Identity.unwrap(self));

        bytes memory outBytes = vm.ffi(cmd);
        string memory outStr = string(outBytes);
        string[] memory pubs = LibString.split(outStr, " ");

        pubUint[0] = vm.parseUint(pubs[0]);
        pubUint[1] = vm.parseUint(pubs[1]);
    }

    function _signHash(Identity self, bytes32 hash) internal returns (bytes memory signature) {
        string[] memory cmd = new string[](5);
        cmd[0] = "pnpm";
        cmd[1] = "semaphore-identity";
        cmd[2] = "sign";
        cmd[3] = vm.toString(Identity.unwrap(self));
        cmd[4] = vm.toString(hash);

        bytes memory outBytes = vm.ffi(cmd);
        string memory outStr = string(outBytes);
        string[] memory signs = LibString.split(outStr, " ");

        uint256 s0 = vm.parseUint(signs[0]);
        uint256 s1 = vm.parseUint(signs[1]);
        uint256 s2 = vm.parseUint(signs[2]);
        signature = abi.encodePacked(s0, s1, s2);
    }
}
