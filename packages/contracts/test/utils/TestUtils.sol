// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Vm } from "forge-std/Vm.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ISemaphore } from "src/interfaces/Semaphore.sol";
import { LibString } from "solady/Milady.sol";

// https://github.com/foundry-rs/forge-std/blob/master/src/Base.sol#L9
address constant VM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
Vm constant vm = Vm(VM_ADDRESS);

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

function getTestUserOpCallData(
    address target,
    uint256 value,
    bytes memory txCallData
)
    pure
    returns (bytes memory callData)
{
    callData = bytes.concat(new bytes(100), bytes20(target), bytes32(value), txCallData);
}

function getGroupRmMerkleProof(
    uint256[] memory members,
    uint256 removal
)
    returns (uint256[] memory merkleProof, uint256 root)
{
    string[] memory cmd = new string[](5);
    cmd[0] = "node";
    cmd[1] = "node_modules/@semaphore-protocol/group/dist/cli.js";
    cmd[2] = "remove-member";
    cmd[3] = joinUint(members);
    cmd[4] = LibString.toString(removal);

    bytes memory outBytes = vm.ffi(cmd);
    string memory outStr = string(outBytes);
    string[] memory retStr = LibString.split(outStr, " ");

    merkleProof = splitToUint(retStr[0]);
    root = vm.parseUint(retStr[1]);
}

function splitToUint(string memory str) pure returns (uint256[] memory retArr) {
    string[] memory arr = LibString.split(str, ",");
    retArr = new uint256[](arr.length);
    for (uint256 i = 0; i < arr.length; i++) {
        retArr[i] = vm.parseUint(arr[i]);
    }
}

function joinUint(uint256[] memory members) pure returns (string memory retStr) {
    for (uint256 i = 0; i < members.length; i++) {
        retStr = string.concat(retStr, LibString.toString(members[i]));
        if (i < members.length - 1) {
            retStr = string.concat(retStr, ",");
        }
    }
}

type Identity is bytes32;

library IdentityLib {
    function genIdentity(uint256 seed) public view returns (Identity) {
        return Identity.wrap(keccak256(abi.encodePacked(seed, address(this))));
    }

    function publicKey(Identity self) public returns (uint256[2] memory) {
        return IdentityLib._publicKey(self);
    }

    function commitment(Identity self) public returns (uint256 cmt) {
        // This is using the identity-cli javascript call, instead of identity
        string[] memory cmd = new string[](4);
        cmd[0] = "node";
        cmd[1] = "node_modules/@semaphore-protocol/identity/dist/cli.js";
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

    function getSempahoreProof(
        Identity self,
        uint256[] memory members,
        bytes32 scope,
        string calldata message
    )
        public
        returns (ISemaphore.SemaphoreProof memory proof)
    {
        string[] memory cmd = new string[](7);
        cmd[0] = "node";
        cmd[1] = "node_modules/@semaphore-protocol/proof/dist/cli.js";
        cmd[2] = "gen-proof";
        cmd[3] = vm.toString(Identity.unwrap(self));
        cmd[4] = IdentityLib._uint256ArrToString(members);
        cmd[5] = LibString.toHexString(uint256(scope));
        cmd[6] = message;

        bytes memory outBytes = vm.ffi(cmd);
        string memory outStr = string(outBytes);

        uint256[] memory points = vm.parseJsonUintArray(outStr, "$.points");
        proof = ISemaphore.SemaphoreProof({
            merkleTreeDepth: vm.parseJsonUint(outStr, "$.merkleTreeDepth"),
            merkleTreeRoot: vm.parseJsonUint(outStr, "$.merkleTreeRoot"),
            nullifier: vm.parseJsonUint(outStr, "$.nullifier"),
            message: vm.parseJsonUint(outStr, "$.message"),
            scope: vm.parseJsonUint(outStr, "$.scope"),
            points: [
                points[0],
                points[1],
                points[2],
                points[3],
                points[4],
                points[5],
                points[6],
                points[7]
            ]
        });
    }

    function _uint256ArrToString(uint256[] memory arr)
        internal
        pure
        returns (string memory retStr)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (i == arr.length - 1) {
                retStr = string.concat(retStr, LibString.toString(arr[i]));
            } else {
                retStr = string.concat(retStr, LibString.toString(arr[i]), ",");
            }
        }
    }

    function _publicKey(Identity self) internal returns (uint256[2] memory pubUint) {
        string[] memory cmd = new string[](4);
        cmd[0] = "node";
        cmd[1] = "node_modules/@semaphore-protocol/identity/dist/cli.js";
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
        cmd[0] = "node";
        cmd[1] = "node_modules/@semaphore-protocol/identity/dist/cli.js";
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

/*//////////////////////////////////////////////////////////////////////////
                        Simple Test Contract
//////////////////////////////////////////////////////////////////////////*/

contract SimpleContract {
    uint256 public val;

    event ValueSet(address indexed account, uint256 indexed value, uint256 indexed newVal);

    constructor(uint256 _val) {
        val = _val;
    }

    function setVal(uint256 newVal) external payable returns (uint256) {
        val = newVal;
        emit ValueSet(msg.sender, msg.value, val);
        return val;
    }
}
