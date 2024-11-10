// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { ISemaphore } from "@semaphore-protocol/contracts/interfaces/ISemaphore.sol";
import { ISemaphoreGroups } from "@semaphore-protocol/contracts/interfaces/ISemaphoreGroups.sol";

contract SemaphoreValidator is ERC7579ValidatorBase {
    // custom errors
    error NotAdmin();
    error ModuleAlreadyInstalled();
    error ModuleNotInstalled();

    /**
     * Constants & Storage
     *
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address => bool) public inUse;
    mapping(address => uint256) public gIds;

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
        moduleNotInstalled
    {
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data
        address admin = abi.decode(data, (address));
        uint256 gId = semaphore.createGroup(admin);
        inUse[msg.sender] = true;
        gIds[msg.sender] = gId;

        // Add the EOA admin as a member
        uint256 commitment = _getUserCommitment(admin);
        semaphore.addMember(gId, commitment);
    }

    function onUninstall(bytes calldata data) external override
        moduleInstalled
        isAdmin(data)
    {
        // remove from our data structure
        delete inUse[msg.sender];
        delete gIds[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return inUse[smartAccount];
    }

    function _getUserCommitment(address addr) internal returns (uint256) {
        // TODO: implement this
        return uint256(0);
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
        return _packValidationData(true, type(uint48).max, 0);
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
