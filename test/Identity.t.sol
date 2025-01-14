// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// forge
import { Test } from "forge-std/Test.sol";

import { Identity as IdentityT } from "../src/utils/Identity.sol";
import { Identity, IdentityLib } from "./utils/TestUtils.sol";

contract IdentityTest is Test {
    using IdentityLib for Identity;

    function test_verifySignatureAcceptCorrectSignature1() public {
        uint256 seed = 13;
        bytes32 hash = bytes32(keccak256("hello world"));

        Identity id = IdentityLib.genIdentity(seed);
        bytes memory signature = id.signHash(hash);

        assertEq(true, IdentityT.verifySignature(hash, signature));
    }

    function test_verifySignatureAcceptCorrectSignature2() public {
        bytes32 hash = hex"00b917632b69261f21d20e0cabdf9f3fa1255c6e500021997a16cf3a46d80297";
        bytes memory signature = hex"26c3a847609100b3fd926d3c0a61324a32479d5989f01383aca537869cb23a851d67a417abb29f71e1f7c3d0bcd93cb68f89203b046174f03c3822a9139b512611b5289e52e9f70ff4a30cb9a19d66de49266887d3d17ed35f2dfc30f44573dc0c44756c4e4c5a5e5eeacc68f39b4e2238041e70ca926139ea039e260ea7ca5000b8d0dfc37fc5de7b0f80b722f8966a43caa10c8068cf863e5d06f82ae7c9d8";

        assertEq(true, IdentityT.verifySignature(hash, signature));
    }

    function test_verifySignatureRejectIncorrectSignature() public {
        uint256 seed = 13;
        bytes32 hash = bytes32(keccak256("hello world"));

        Identity id = IdentityLib.genIdentity(seed);
        bytes memory signature = id.signHash(hash);
        signature[0] = hex"ff";
        signature[1] = hex"ff";

        assertEq(false, IdentityT.verifySignature(hash, signature));
    }
}
