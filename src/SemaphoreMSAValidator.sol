// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { ISemaphore, ISemaphoreGroups } from "./utils/Semaphore.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    using LibSort for *;
    // using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    // Constants
    uint8 constant MAX_MEMBERS = 32;

    // OwnableValidator errors
    error CannotRemoveOwner();
    error InvalidIdCommitment();
    error InvalidThreshold();
    error MaxMemberReached();
    error NotSortedAndUnique();
    error MemberNotExists(address, uint256);
    error IsOwnerAlready(address, uint256);

    // Events
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);

    // OwnableValidator events
    event AddedMember(address indexed, uint256 indexed);
    event RemovedMember(address indexed, uint256 indexed);
    event ThresholdSet(address indexed account, uint8 indexed);

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address => uint256) public groupMapping;
    mapping(address account => uint8) public thresholds;
    mapping(address account => uint8) public cmtCount;

    constructor(ISemaphore _semaphore) {
        semaphore = _semaphore;
        groups = ISemaphoreGroups(address(_semaphore));
    }

    modifier moduleInstalled() {
        if (thresholds[msg.sender] == 0) revert NotInitialized(msg.sender);
        _;
    }

    /**
     * Config
     */
    function isInitialized(address account) external view override returns (bool) {
        return thresholds[account] > 0;
    }

    function onInstall(bytes calldata data) external override {
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data

        // Ensure the module isn't installed already for the smart account
        address account = msg.sender;
        if (thresholds[account] > 0) revert AlreadyInitialized(account);

        // OwnableValidator
        (uint8 threshold, uint256[] memory cmts) = abi.decode(data, (uint8, uint256[]));

        // Check all address are valid
        (bool found,) = cmts.searchSorted(uint256(0));
        if (found) revert InvalidIdCommitment();

        if (!cmts.isSortedAndUniquified()) revert NotSortedAndUnique();

        // Check the relation between threshold and ownersLen are valid
        if (cmts.length > MAX_MEMBERS) revert MaxMemberReached();

        uint8 cmtLen = uint8(cmts.length);
        if (cmtLen == 0 || cmtLen < threshold) revert InvalidThreshold();

        // Completed all checks by this point. Write to the storage.
        thresholds[account] = threshold;
        cmtCount[account] = cmtLen;

        uint256 groupId = semaphore.createGroup();
        groupMapping[account] = groupId;

        // Add members to the group
        semaphore.addMembers(groupId, cmts);

        emit ModuleInitialized(account);
    }

    function onUninstall(bytes calldata) external override moduleInstalled {
        // remove from our data structure
        address account = msg.sender;
        delete thresholds[account];
        delete cmtCount[account];
        delete groupMapping[account];

        emit ModuleUninitialized(account);
    }

    function setThreshold(uint8 newThreshold) external moduleInstalled {
        address account = msg.sender;
        if (newThreshold == 0 || newThreshold > cmtCount[account]) revert InvalidThreshold();

        thresholds[account] = newThreshold;
        emit ThresholdSet(account, newThreshold);
    }

    function addMember(uint256 cmt) external moduleInstalled {
        address account = msg.sender;
        // 0. check the module is initialized for the acct
        // 1. check newOwner != 0
        // 2. check ownerCount < MAX_MEMBERS
        // 3. cehck owner not existed yet
        if (cmt == uint256(0)) revert InvalidIdCommitment();
        if (cmtCount[account] == MAX_MEMBERS) revert MaxMemberReached();

        uint256 groupId = groupMapping[account];

        if (groups.hasMember(groupId, cmt)) revert IsOwnerAlready(account, cmt);

        semaphore.addMember(groupId, cmt);
        cmtCount[account] += 1;

        emit AddedMember(account, cmt);
    }

    function removeMember(uint256 rmOwner) external moduleInstalled {
        address account = msg.sender;

        if (cmtCount[account] == thresholds[account]) revert CannotRemoveOwner();
        uint256 groupId = groupMapping[account];
        if (!groups.hasMember(groupId, rmOwner)) revert MemberNotExists(account, rmOwner);

        cmtCount[account] -= 1;

        // TODO: add the 3rd param: merkleProofSiblings
        semaphore.removeMember(groupId, rmOwner, new uint256[](0));

        emit RemovedMember(account, rmOwner);
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
        returns (bool validSig)
    {
        return true;
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
        return "SemaphoreMSAValidator";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.1.0";
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
