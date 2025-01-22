// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import { console } from "forge-std/console.sol";

contract SimpleContract {
    uint256 public val;

    event ValueSet(address indexed account, uint256 indexed value, uint256 indexed newVal);

    constructor(uint256 _val) {
        val = _val;
    }

    function setVal(uint256 newVal) external payable returns (uint256) {
        // console.log("SimpleContract setVal()");
        val = newVal;
        emit ValueSet(msg.sender, msg.value, val);
        return val;
    }
}
