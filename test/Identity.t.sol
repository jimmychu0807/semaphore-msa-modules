// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// forge
import { Test } from "forge-std/Test.sol";

import { Identity as IdentityT } from "../src/utils/Identity.sol";
import { Identity, IdentityLib } from "./utils/TestUtils.sol";

contract IdentityTest is Test {
    using IdentityLib for Identity;

    function test_verifySignatureAcceptCorrectSignature() public {
        uint256 seed = 13;
        bytes32 hash = bytes32(keccak256("hello world"));

        Identity id = IdentityLib.genIdentity(seed);
        bytes memory signature = id.signHash(hash);

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
