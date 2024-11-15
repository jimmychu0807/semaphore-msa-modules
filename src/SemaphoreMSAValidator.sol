// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { CheckSignatures } from "checknsignatures/CheckNSignatures.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { ISemaphore } from "semaphore/interfaces/ISemaphore.sol";
import { ISemaphoreGroups } from "semaphore/interfaces/ISemaphoreGroups.sol";

import { console } from "forge-std/console.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    using LibSort for *;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    // Constants
    uint8 constant MAX_OWNERS = 32;

    // custom errors
    error NotAdmin();
    error ModuleAlreadyInstalled();
    error ModuleNotInstalled();

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address => bool) public inUse;
    mapping(address => uint256) public gIds;

    SentinelList4337Lib.SentinelList owners;
    mapping(address account => uint8) public threshold;
    mapping(address account => uint8) public ownerCount;

    // In the Semaphore contract, the admin for any group is the SemaphoreValidator contract.
    // We store the actual smart account admin here. There can only be one admin for now.
    mapping(address => address) public admins;

    // SemaphoreValidator contract has to be the admin of the Semaphore contract

    constructor(ISemaphore _semaphore) {
        semaphore = _semaphore;
        groups = ISemaphoreGroups(address(_semaphore));
    }

    modifier moduleInstalled() {
        if (!inUse[msg.sender]) {
            revert ModuleNotInstalled();
        }
        _;
    }

    modifier moduleNotInstalled() {
        if (inUse[msg.sender]) {
            revert ModuleAlreadyInstalled();
        }
        _;
    }

    modifier isAdmin(bytes calldata data) {
        address user = abi.decode(data, (address));
        uint256 gId = gIds[msg.sender];
        address admin = groups.getGroupAdmin(gId);
        if (user != admin) {
            revert NotAdmin();
        }
        _;
    }

    /**
     * Config
     *
     */
    function onInstall(bytes calldata data) external override
    {
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data
        (address admin, uint256 commitment) = abi.decode(data, (address, uint256));
        uint256 gId = semaphore.createGroup();
        inUse[msg.sender] = true;
        gIds[msg.sender] = gId;
        admins[msg.sender] = admin;

        // Add the admin commitment in as the first group member.
        semaphore.addMember(gId, commitment);
    }

    function onUninstall(bytes calldata data) external override
        moduleInstalled
        isAdmin(data)
    {
        // remove from our data structure
        delete inUse[msg.sender];
        delete gIds[msg.sender];
        delete admins[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return inUse[smartAccount];
    }

    /**
     * Module logic
     *
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        bool sigFailed = false;
        (uint256 sender, bytes memory _signature) = abi.decode(userOp.signature, (uint256, bytes));

        return _packValidationData(!sigFailed, type(uint48).max, 0);
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sugValidationResult)
    {
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

    function addMember(uint256 memberCommitment) external
        moduleInstalled
    {
        // The gId of the smart account
        uint256 gId = gIds[msg.sender];

        // TODO: perform checking & error handling once this work
        semaphore.addMember(gId, memberCommitment);
    }

    function removeMember(uint256 identityCommitment, uint256[] calldata merkleProofSiblings) external
        moduleInstalled
    {
        // The gId of the smart account
        uint256 gId = gIds[msg.sender];
        semaphore.removeMember(gId, identityCommitment, merkleProofSiblings);
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
