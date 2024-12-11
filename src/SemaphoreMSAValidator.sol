// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// When you need this lib contract, copy it from @rhinestone and put it in lib/ folders
// import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { CheckSignatures } from "src/utils/CheckSignatures.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { ISemaphore } from "semaphore/interfaces/ISemaphore.sol";
import { ISemaphoreGroups } from "semaphore/interfaces/ISemaphoreGroups.sol";

import { console } from "forge-std/console.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    using LibSort for *;
    // using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    // Constants
    uint8 constant MAX_OWNERS = 32;

    // custom errors
    error AlreadyInitialized(address);

    // OwnableValidator errors
    error CannotRemoveOwner();
    error InvalidOwner();
    error InvalidThreshold();
    error IsOwnerAlready();
    error MaxOwnersReached();
    error NotSortedAndUnique();
    error OwnerNotExisted(address, address);
    error ThresholdNotReached();

    // Events
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);

    // OwnableValidator events
    event AddedOwner(address indexed, address indexed);
    event RemovedOwner(address indexed, address indexed);
    event ThresholdSet(address indexed account, uint8 indexed);

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address => uint256) public groupMapping;
    mapping(address account => uint8) public threshold;
    mapping(address account => uint8) public ownerCount;

    constructor(ISemaphore _semaphore) {
        semaphore = _semaphore;
        groups = ISemaphoreGroups(address(_semaphore));
    }

    modifier moduleInstalled() {
        if (threshold[msg.sender] == 0) revert NotInitialized(msg.sender);
        _;
    }

    /**
     * Config
     */
    function isInitialized(address account) public view returns (bool) {
        return threshold[account] > 0;
    }

    function onInstall(bytes calldata data) external override {
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data

        // Ensure the module isn't installed already for the smart account
        if (threshold[msg.sender] > 0) revert AlreadyInitialized(msg.sender);


        // OwnableValidator
        (uint8 _threshold, uint256[] memory _owners) = abi.decode(data, (uint8, uint256[]));

        // Check all address are valid
        (bool found,) = _owners.searchSorted(address(0));
        if (found) revert InvalidOwner();

        if (!_owners.isSortedAndUniquified()) revert NotSortedAndUnique();

        // Check the relation between threshold and ownersLen are valid
        uint8 ownersLength = uint8(_owners.length);
        if (_threshold == 0 || ownersLength < _threshold) revert InvalidThreshold();
        if (_threshold > MAX_OWNERS) revert MaxOwnersReached();

        // Completed all checks by this point. Write to the storage.
        address account = msg.sender;
        threshold[account] = _threshold;
        ownerCount[account] = ownersLength;

        uint256 groupId = semaphore.createGroup();
        groupMapping[account] = groupId;

        // Add members to the group
        semaphore.addMembers(groupId, idComms);

        emit ModuleInitialized(account);
    }

    function onUninstall(bytes calldata) external override
        moduleInstalled()
    {
        // remove from our data structure
        address account = msg.sender;
        delete threshold[account];
        delete ownerCount[account];
        delete groupMapping[account];

        emit ModuleUninitialized(account);
    }

    function setThreshold(uint8 newThreshold) external
        moduleInstalled()
    {
        if (newThreshold == 0 || newThreshold > ownerCount[msg.sender]) revert InvalidThreshold();

        threshold[msg.sender] = newThreshold;
        emit ThresholdSet(msg.sender, newThreshold);
    }

    // NX: Up to this point
    function addOwner(address newOwner) external {
        if (!isInitialized(msg.sender)) { revert NotInitialized(msg.sender); }
        // 0. check the module is initialized for the acct
        // 1. check newOwner != 0
        // 2. check ownerCount < MAX_OWNERS
        // 3. cehck owner not existed yet
        if (newOwner == address(0)) { revert InvalidOwner(); }
        if (ownerCount[msg.sender] == MAX_OWNERS) { revert MaxOwnersReached(); }
        if (owners.contains(msg.sender, newOwner)) { revert IsOwnerAlready(); }

        owners.push(msg.sender, newOwner);
        ownerCount[msg.sender] += 1;
        emit AddedOwner(msg.sender, newOwner);
    }

    function removeOwner(address prevOwner, address owner) external {
        if (!isInitialized(msg.sender)) { revert NotInitialized(msg.sender); }
        // 1. cannot be lower then threshold after removal
        // 2. owner existed
        // note: DX is bad that I need to specify a prevOwner in removal
        if (ownerCount[msg.sender] == threshold[msg.sender]) { revert CannotRemoveOwner(); }
        if (!owners.contains(msg.sender, owner)) { revert OwnerNotExisted(msg.sender, owner); }

        threshold[msg.sender] -= 1;
        owners.pop(msg.sender, prevOwner, owner);
        emit RemovedOwner(msg.sender, owner);
    }

    function getOwners(address account) external view returns (address[] memory ownersArr) {
        (ownersArr,) = owners.getEntriesPaginated(account, SENTINEL, MAX_OWNERS);
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
