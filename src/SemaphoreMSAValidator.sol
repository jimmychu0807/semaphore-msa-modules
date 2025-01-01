// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import {
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { LibBytes } from "solady/utils/LibBytes.sol";

import { ISemaphore, ISemaphoreGroups } from "./utils/Semaphore.sol";
import { Identity } from "./utils/Identity.sol";
// import { console } from "forge-std/console.sol";

// Ensure the following match with the 3 function calls.
bytes4 constant INITIATE_TX_SEL = bytes4(
    abi.encodeCall(
        SemaphoreMSAValidator.initiateTx,
        ("", ISemaphore.SemaphoreProof(0, 0, 0, 0, 0, [uint256(0), 0, 0, 0, 0, 0, 0, 0]), false)
    )
);

bytes4 constant SIGN_TX_SEL = bytes4(
    abi.encodeCall(
        SemaphoreMSAValidator.signTx,
        ("", ISemaphore.SemaphoreProof(0, 0, 0, 0, 0, [uint256(0), 0, 0, 0, 0, 0, 0, 0]), false)
    )
);

bytes4 constant EXECUTE_TX_SEL = bytes4(abi.encodeCall(SemaphoreMSAValidator.executeTx, ("")));

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    using LibSort for *;

    // Constants
    uint8 public constant MAX_MEMBERS = 32;

    struct CallDataCount {
        bytes callData;
        uint8 sigCount;
    }

    // Errors
    error CannotRemoveOwner();
    error InvalidIdCommitment();
    error InvalidThreshold();
    error MaxMemberReached();
    error NotSortedAndUnique();
    error MemberNotExists(address account, uint256 cmt);
    error IsMemberAlready(address acount, uint256 cmt);
    error TxHasBeenInitiated(address account, bytes32 txHash);
    error TxHashNotFound(address account, bytes32 txHash);
    error ThresholdNotReach(address account, uint8 threshold, uint8 current);
    error TxAndProofDontMatch(address account, bytes32 txHash);
    error InvalidSignatureLen(address account, uint256 len);
    error InvalidUserOpSignature(address account, bytes32 userOpHash, bytes signature);

    // Events
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);
    event AddedMember(address indexed, uint256 indexed commitment);
    event RemovedMember(address indexed, uint256 indexed commitment);
    event ThresholdSet(address indexed account, uint8 indexed threshold);
    event InitiatedTx(address indexed account, bytes32 indexed txHash);
    event SignedTx(address indexed account, bytes32 indexed txHash);
    event ExecutedTx(address indexed account, bytes32 indexed txHash);

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address account => uint256 groupId) public groupMapping;
    mapping(address account => uint8 threshold) public thresholds;

    // smart account -> hash(call(params)) -> valid proof count
    mapping(address account => mapping(bytes32 txHash => CallDataCount callDataCount)) public
        acctTxCount;

    // keep track of seqNum of txs that require threshold signature
    mapping(address account => uint256 seqNum) public acctSeqNum;

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

        // console.log("bytes:");
        // console.logBytes(data);

        // OwnableValidator
        (uint8 threshold, uint256[] memory cmts) = abi.decode(data, (uint8, uint256[]));

        // console.log("threshold: %s, cmt len: %s", threshold, cmts.length);
        // console.log("cmt: %s", cmts[0]);

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
        delete groupMapping[account];
        delete acctSeqNum[account];

        //TODO: what is a good way to delete entries associated with `acctTxCount[account]`,
        //   The following line will make the compiler fail.
        // delete acctTxCount[account];

        emit ModuleUninitialized(account);
    }

    function memberCount(address account) public view returns (uint8 cnt) {
        // account doesn't belong to a semaphore group. We return 0
        if (thresholds[account] == 0) return 0;
        cnt = uint8(groups.getMerkleTreeSize(groupMapping[account]));
    }

    function setThreshold(uint8 newThreshold) external moduleInstalled {
        address account = msg.sender;
        if (newThreshold == 0 || newThreshold > memberCount(account)) revert InvalidThreshold();

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
        if (memberCount(account) == MAX_MEMBERS) revert MaxMemberReached();

        uint256 groupId = groupMapping[account];

        if (groups.hasMember(groupId, cmt)) revert IsMemberAlready(account, cmt);

        semaphore.addMember(groupId, cmt);

        emit AddedMember(account, cmt);
    }

    function removeMember(uint256 rmOwner) external moduleInstalled {
        address account = msg.sender;

        if (memberCount(account) == thresholds[account]) revert CannotRemoveOwner();

        uint256 groupId = groupMapping[account];
        if (!groups.hasMember(groupId, rmOwner)) revert MemberNotExists(account, rmOwner);

        //TODO: add the 3rd param: merkleProofSiblings. Now I set it to 0 to make it passes the
        // compiler
        semaphore.removeMember(groupId, rmOwner, new uint256[](0));

        emit RemovedMember(account, rmOwner);
    }

    function getNextSeqNum(address account) external returns (uint256) {
        return acctSeqNum[account];
    }

    function initiateTx(
        bytes calldata callData,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        moduleInstalled
        returns (bytes32 txHash)
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        // By this point, txParams should be validated.
        // combine the txParams with the account nonce and compute its hash
        uint256 seq = acctSeqNum[account];
        txHash = keccak256(abi.encode(callData, seq));

        // Check: validate the proof is related to the callData
        if (groupId != proof.scope || uint256(txHash) != proof.message) {
            revert TxAndProofDontMatch(account, txHash);
        }

        CallDataCount storage cdc = acctTxCount[account][txHash];
        if (cdc.sigCount != 0) revert TxHasBeenInitiated(account, txHash);

        // the callData and proof should have some kind of inherent relationship
        semaphore.validateProof(groupId, proof);

        //TODO: how do you handle plain chain native tokens transfer?

        // By this point, the proof also passed semaphore check.
        // Start writing to the storage
        acctSeqNum[account] += 1;
        cdc.callData = callData;
        cdc.sigCount = 1;

        emit InitiatedTx(account, txHash);

        // execute the transaction if condition allows
        if (execute && cdc.sigCount >= thresholds[account]) executeTx(txHash);
    }

    function signTx(
        bytes32 txHash,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        moduleInstalled
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        if (proof.scope != groupId) revert TxAndProofDontMatch(account, txHash);

        // Check if the txHash exist
        CallDataCount storage cdc = acctTxCount[account][txHash];
        if (cdc.sigCount == 0) revert TxHashNotFound(account, txHash);

        semaphore.validateProof(groupId, proof);

        cdc.sigCount += 1;
        emit SignedTx(account, txHash);

        // execute the transaction if condition allows
        if (execute && cdc.sigCount >= thresholds[account]) executeTx(txHash);
    }

    function executeTx(bytes32 txHash) public moduleInstalled {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];
        uint8 threshold = thresholds[account];
        CallDataCount storage cdc = acctTxCount[account][txHash];

        if (cdc.sigCount == 0) revert TxHashNotFound(account, txHash);
        if (cdc.sigCount < threshold) revert ThresholdNotReach(account, threshold, cdc.sigCount);

        //TODO: make the actual contract call here

        emit ExecutedTx(account, txHash);

        // Clean up the storage
        delete acctTxCount[account][txHash];
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
        // view
        override
        returns (ValidationData)
    {
        // you want to exclude initiateTx, signTx, executeTx from needing tx count.
        // you just need to ensure they are a valid proof from the semaphore group members
        address account = userOp.sender;
        uint256 groupId = groupMapping[account];

        // The userOp.signature is 160 bytes containing:
        //   (uint256 pubX (32 bytes), uint256 pubY (32 bytes), bytes[96] signature (96 bytes))
        if (userOp.signature.length != 160) {
            revert InvalidSignatureLen(account, userOp.signature.length);
        }

        // Verify signature using the public key
        if (!Identity.verifySignature(userOpHash, userOp.signature)) {
            revert InvalidUserOpSignature(account, userOpHash, userOp.signature);
        }

        // Verify if the identity commitment is one of the semaphore group members
        bytes memory pubKey = LibBytes.slice(userOp.signature, 0, 66);
        uint256 cmt = Identity.getCommitment(pubKey);

        if (!groups.hasMember(groupId, cmt)) revert MemberNotExists(account, cmt);

        // Validate the userOp.callData length before extracting 4 bytes out
        (bytes4 funcSel) = abi.decode(userOp.callData, (bytes4));

        // Allow only these three types on function calls to pass, and reject all other on-chain
        //   calls. They must be executed via `executeTx()` function.
        if ((funcSel == INITIATE_TX_SEL) || (funcSel == SIGN_TX_SEL) || (funcSel == EXECUTE_TX_SEL))
        {
            return VALIDATION_SUCCESS;
        }

        return VALIDATION_FAILED;
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
