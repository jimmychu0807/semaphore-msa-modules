// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { Vm } from "forge-std/Vm.sol";

library FFIUtils {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  function ls() public returns (string memory output) {
    string[] memory inputs = new string[](2);
    inputs[0] = ("ls");
    inputs[1] = ("-l");

    bytes memory res = vm.ffi(inputs);
    output = abi.decode(res, (string));
    return output;
  }
}
