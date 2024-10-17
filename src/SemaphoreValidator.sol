// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import {ISemaphore} from "@semaphore-protocol/interfaces/ISemaphore.sol";
import {ISemaphoreGroups} from "@semaphore-protocol/interfaces/ISemaphoreGroups.sol";

import { console } from "forge-std/console.sol";

contract SemaphoreValidator is ERC7579ValidatorBase {
  // custom errors
  error UserNotAdmin(uint256 gId, address user);
  error SemaphoreValidatorAlreadyInstalled(address acct);
  error ModuleNotInstalled(address acct);

  /**
   * Constants & Storage
   **/
  ISemaphore public semaphore;
  ISemaphoreGroups public groups;
  mapping (address => bool) public inUse;
  mapping (address => uint256) public gIds;

  constructor(ISemaphore _semaphore) {
    semaphore = _semaphore;
    groups = ISemaphoreGroups(address(_semaphore));
  }

  /**
   * Config
   **/
  function onInstall(bytes calldata data) external override {
    // Check the smart acct has not been initialized yet
    if (inUse[msg.sender]) {
      revert SemaphoreValidatorAlreadyInstalled(msg.sender);
    }

    // create a new group
    // msg.sender is the smart wallet that call this contract
    // you often have to parse the passed in parameters to get the original caller
    // The address of the original caller (the one who sends http request to the bundler) must be passed in from data
    address admin = abi.decode(data, (address));
    uint256 gId = semaphore.createGroup(admin);
    inUse[msg.sender] = true;
    gIds[msg.sender] = gId;
  }

  function onUninstall(bytes calldata data) external override {
    (uint256 gId, address user) = abi.decode(data, (uint256, address));

    address admin = groups.getGroupAdmin(gId);
    if (user != admin) {
      revert UserNotAdmin(gId, user);
    }

    // deactivate the group
    inUse[msg.sender] = false;

    // We don't change the gId of the smart acct
  }

  function isInitialized(address smartAccount) external view returns (bool) {
    return inUse[smartAccount];
  }

  /**
   * Module logic
   **/
  function validateUserOp (
    PackedUserOperation calldata userOp,
    bytes32 userOpHash
  ) external view override returns (ValidationData) {

      return _packValidationData(true, type(uint48).max, 0);
  }

  function isValidSignatureWithSender(
    address sender,
    bytes32 hash,
    bytes calldata signature
  ) external view virtual override returns (bytes4 sugValidationResult) {
    return EIP1271_SUCCESS;
  }

  function validateSignatureWithData(
    bytes32,
    bytes calldata,
    bytes calldata
  )
    external
    view
    virtual
    override
    returns (bool validSig)
  {
    return true;
  }

  function addMembers(address user, uint256 gId, uint256[] calldata memberCommitments) external {
    if (!inUse[msg.sender]) {
      revert ModuleNotInstalled(msg.sender);
    }

    address admin = groups.getGroupAdmin(gId);
    if (user != admin) {
      revert UserNotAdmin(gId, user);
    }

    semaphore.addMembers(gId, memberCommitments);
  }

  /*//////////////////////////////////////////////////////////////////////////
                                   METADATA
  //////////////////////////////////////////////////////////////////////////*/

  /**
   * The name of the module
   *
   * @return name The name of the module
   */
  function name() external pure returns (string memory) {
    return "SemaphoreValidator";
  }

  /**
   * The version of the module
   *
   * @return version The version of the module
   */
  function version() external pure returns (string memory) {
    return "0.0.1";
  }

  /**
   * Check if the module is of a certain type
   *
   * @param typeID The type ID to check
   *
   * @return true if the module is of the given type, false otherwise
   */
  function isModuleType(uint256 typeID) external pure override returns (bool) {
    return typeID == TYPE_VALIDATOR;
  }
}
