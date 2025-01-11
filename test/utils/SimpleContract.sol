// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract SimpleContract {
    uint256 public val;

    constructor(uint256 _val) {
        val = _val;
    }

    function setVal(uint256 newVal) public returns (uint256) {
        val = newVal;
        return val;
    }
}
