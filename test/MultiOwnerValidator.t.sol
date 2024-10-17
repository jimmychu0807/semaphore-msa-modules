// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
  RhinestoneModuleKit,
  ModuleKitHelpers,
  ModuleKitUserOp,
  AccountInstance,
  UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { MultiOwnerValidator } from "src/MultiOwnerValidator.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract MultiOwnerValidatorTest is RhinestoneModuleKit, Test {
  using ModuleKitHelpers for *;
  using ModuleKitUserOp for *;
  using ECDSA for bytes32;

  AccountInstance internal instance;
  MultiOwnerValidator internal validator;

  Account owner1;
  Account owner2;

  function setUp() public {
    init();

    // Create the validator
    validator = new MultiOwnerValidator();
    vm.label(address(validator), "MultiOwnerValidator");

    // Create the owners
    owner1 = makeAccount("owner1");
    owner2 = makeAccount("owner2");

    // Create the acct and install the validator
    instance = makeAccountInstance("MultiOwnerValidator");
    vm.deal(address(instance.account), 10 ether);
    instance.installModule({
      moduleTypeId: MODULE_TYPE_VALIDATOR,
      module: address(validator),
      data: abi.encodePacked(owner1.addr)
    });
  }

  function signHash(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ECDSA.toEthSignedMessageHash(digest));
    return abi.encodePacked(r, s, v);
  }

  function execAndAssert(uint256 ownerId, uint256 key) internal {
    address target = makeAddr("target");
    uint256 value = 1 ether;
    uint256 prevBal = target.balance;

    UserOpData memory userOpData = instance.getExecOps({
      target: target,
      value: value,
      callData: "",
      txValidator: address(validator)
    });

    // Set the signature
    bytes memory signature = signHash(key, userOpData.userOpHash);
    userOpData.userOp.signature = abi.encode(ownerId, signature);

    // Execute the UserOp
    userOpData.execUserOps();

    assertEq(target.balance, prevBal + value);
  }

  function testOwner1() public {
    instance.log4337Gas("testOwner1-gas");

    execAndAssert(0, owner1.key);
  }

  function testOwner2() public {
    instance.log4337Gas("testOwner2-gas");

    instance.exec({
      target: address(validator),
      callData: abi.encodeWithSelector(
        MultiOwnerValidator.addOwner.selector,
        uint256(1),
        owner2.addr
      )
    });
    execAndAssert(1, owner2.key);
  }
}
