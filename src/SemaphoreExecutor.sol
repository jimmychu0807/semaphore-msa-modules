// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone module-kit
import { IERC7579Account } from "modulekit/Accounts.sol";
import { ERC7579ExecutorBase, IERC7579Module } from "modulekit/Modules.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";

import { LibBytes, LibSort } from "solady/Milady.sol";
import { ISemaphore, ISemaphoreGroups } from "src/interfaces/Semaphore.sol";
import { ISemaphoreValidator } from "src/interfaces/ISemaphoreValidator.sol";
import { ISemaphoreExecutor } from "src/interfaces/ISemaphoreExecutor.sol";
import { ValidatorLibBytes } from "src/utils/ValidatorLibBytes.sol";
import {
    CMT_BYTELEN,
    MAX_MEMBERS,
    SEMAPHORE_VALIDATOR,
    SEMAPHORE_EXECUTOR,
    VERSION
} from "src/utils/Constants.sol";

struct ExtCallCount {
    address targetAddr;
    bytes callData;
    uint256 value;
    uint8 count;
}

contract SemaphoreExecutor is ISemaphoreExecutor, ERC7579ExecutorBase {
    using LibSort for *;
    using ValidatorLibBytes for bytes;

    /**
     * Errors
     */
    error SemaphoreValidatorSetAlready();
    error InvalidSemaphoreValidator(address addr);
    error MemberCntReachesThreshold(address account);
    error InvalidThreshold(address account);
    error MaxMemberReached(address account);
    error CommitmentsNotUnique();
    error InvalidCommitment(address account);

    error IsMemberAlready(address acount, uint256 cmt);
    error MemberNotExists(address account, uint256 cmt);
    error TxHasBeenInitiated(address account, bytes32 txHash);
    error TxNotFound(address account, bytes32 txHash);
    error ThresholdNotReach(address account, uint8 threshold, uint8 current);
    error InvalidInstallData();
    error InvalidSemaphoreProof(bytes reason);
    error InitiateTxWithNullAddress(address account);
    error ExecuteTxFailure(address account, address targetAddr, uint256 value, bytes callData);
    error SemaphoreValidatorIsInitialized(address account);

    /**
     * Events
     */
    event SemaphoreExecutorInitialized(address indexed account);
    event SemaphoreExecutorUninitialized(address indexed account);
    event SetSemaphoreValidator(address indexed target);
    event ExecutedTx(address indexed account, address indexed target, uint256 indexed value);
    event AddedMembers(address indexed, uint8 indexed length);
    event RemovedMember(address indexed, uint256 indexed commitment);
    event ThresholdSet(address indexed account, uint8 indexed threshold);
    event InitiatedTx(address indexed account, uint256 indexed seq, bytes32 indexed txHash);
    event SignedTx(address indexed account, bytes32 indexed txHash);
    event ExecutedTx(address indexed account, bytes32 indexed txHash);

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    address public semaphoreValidatorAddr;

    mapping(address account => uint256 groupId) public groupMapping;
    mapping(address account => uint8 threshold) public thresholds;
    mapping(address account => uint8 count) public memberCount;

    // smart account -> hash(call(params)) -> valid proof count
    mapping(address account => mapping(bytes32 txHash => ExtCallCount callDataCount)) public
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
        // Ensure the module isn't installed already for the smart account
        address account = msg.sender;
        if (thresholds[account] > 0) revert ModuleAlreadyInitialized(account);

        uint256 dataLen = data.length;

        // here we check if dataLen exist and dataLen, minus the first 8-byte threshold value, is in
        // a multiple of commitment-byte length.
        if (dataLen == 0 || (dataLen - 1) % CMT_BYTELEN != 0) revert InvalidInstallData();

        uint8 threshold = uint8(bytes1(data[:1]));
        bytes memory cmtBytes = data[1:dataLen];
        uint256[] memory cmts = cmtBytes.convertToCmts();

        // Check the relation between threshold and ownersLen are valid
        if (cmts.length > MAX_MEMBERS) revert MaxMemberReached(account);
        if (cmts.length < threshold) revert InvalidThreshold(account);

        // Check no duplicate commitment and no `0`
        cmts.insertionSort();
        if (!cmts.isSortedAndUniquified()) revert CommitmentsNotUnique();
        (bool found,) = cmts.searchSorted(uint256(0));
        if (found) revert InvalidCommitment(account);

        // Completed all checks by this point. Write to the storage.
        thresholds[account] = threshold;

        uint256 groupId = semaphore.createGroup();
        groupMapping[account] = groupId;

        // Add members to the group
        semaphore.addMembers(groupId, cmts);
        memberCount[account] = uint8(cmts.length);

        emit SemaphoreExecutorInitialized(account);
    }

    function onUninstall(bytes calldata) external override {
        address account = msg.sender;

        // Check that the validator has been removed before removing executor
        ISemaphoreValidator semaphoreValidator = ISemaphoreValidator(semaphoreValidatorAddr);
        if (semaphoreValidator.isInitialized(account)) {
            revert SemaphoreValidatorIsInitialized(account);
        }

        // remove from our data structure
        delete thresholds[account];
        delete groupMapping[account];
        delete acctSeqNum[account];
        delete memberCount[account];

        //TODO: what is a good way to delete entries associated with `acctTxCount[account]`,
        //   The following line will make the compiler fail.
        // delete acctTxCount[account];

        emit SemaphoreExecutorUninitialized(account);
    }

    /**
     * Public Reader Functions
     */
    function getAcctSeqNum(address account) external view returns (uint256) {
        return acctSeqNum[account];
    }

    function getGroupId(address account) external view returns (bool, uint256) {
        if (thresholds[account] > 0) return (true, groupMapping[account]);

        return (false, 0);
    }

    function getAcctTx(
        address account,
        bytes32 txHash
    )
        external
        view
        returns (ExtCallCount memory ecc)
    {
        ecc = acctTxCount[account][txHash];
    }

    function accountHasMember(address account, uint256 cmt) external view returns (bool) {
        if (thresholds[account] == 0) return false;

        uint256 groupId = groupMapping[account];
        return groups.hasMember(groupId, cmt);
    }

    /**
     * Set-once Functions
     */
    function setSemaphoreValidator(address target) external {
        if (semaphoreValidatorAddr != address(0)) revert SemaphoreValidatorSetAlready();

        ISemaphoreValidator val = ISemaphoreValidator(target);
        if (
            !LibBytes.eq(bytes(val.name()), bytes(SEMAPHORE_VALIDATOR))
                || !val.isModuleType(TYPE_VALIDATOR)
        ) {
            revert InvalidSemaphoreValidator(target);
        }

        semaphoreValidatorAddr = target;
        emit SetSemaphoreValidator(target);
    }

    /**
     * Main logics
     */
    function setThreshold(uint8 newThreshold) external moduleInstalled {
        address account = msg.sender;
        if (newThreshold == 0 || newThreshold > memberCount[account]) {
            revert InvalidThreshold(account);
        }

        thresholds[account] = newThreshold;
        emit ThresholdSet(account, newThreshold);
    }

    function addMembers(uint256[] calldata cmts) external moduleInstalled {
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        if (memberCount[account] + cmts.length > MAX_MEMBERS) revert MaxMemberReached(account);

        for (uint256 i = 0; i < cmts.length; ++i) {
            if (cmts[i] == uint256(0)) revert InvalidCommitment(account);
            if (groups.hasMember(groupId, cmts[i])) revert IsMemberAlready(account, cmts[i]);
        }

        semaphore.addMembers(groupId, cmts);
        uint8 cmtsLen = uint8(cmts.length);
        memberCount[account] += cmtsLen;
        emit AddedMembers(account, cmtsLen);
    }

    function removeMember(
        uint256 cmt,
        uint256[] calldata merkleProofSiblings
    )
        external
        moduleInstalled
    {
        address account = msg.sender;

        if (memberCount[account] == thresholds[account]) revert MemberCntReachesThreshold(account);

        uint256 groupId = groupMapping[account];
        if (!groups.hasMember(groupId, cmt)) revert MemberNotExists(account, cmt);

        semaphore.removeMember(groupId, cmt, merkleProofSiblings);
        memberCount[account] -= 1;

        emit RemovedMember(account, cmt);
    }

    /**
     * Key logics
     */
    function initiateTx(
        address target,
        uint256 value,
        bytes calldata callData,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        virtual
        moduleInstalled
        returns (bytes32 txHash)
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        // Check target cannot be null
        if (target == address(0)) revert InitiateTxWithNullAddress(account);

        uint256 seq = acctSeqNum[account];
        txHash = keccak256(abi.encodePacked(seq, target, value, callData));

        ExtCallCount storage ecc = acctTxCount[account][txHash];
        if (ecc.count != 0) revert TxHasBeenInitiated(account, txHash);

        // finally, check semaphore proof
        try semaphore.validateProof(groupId, proof) {
            // By this point, the proof also passed semaphore check. Start writing to the storage
            acctSeqNum[account] += 1;
            ecc.targetAddr = target;
            ecc.callData = callData;
            ecc.value = value;
            ecc.count = 1;

            emit InitiatedTx(account, seq, txHash);
            // execute the transaction if condition allows
            if (execute && ecc.count >= thresholds[account]) executeTx(txHash);
        } catch Error(string memory reason) {
            revert InvalidSemaphoreProof(bytes(reason));
        } catch (bytes memory reason) {
            revert InvalidSemaphoreProof(reason);
        }
    }

    function signTx(
        bytes32 txHash,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        virtual
        moduleInstalled
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        // Check if the txHash exist
        ExtCallCount storage ecc = acctTxCount[account][txHash];
        if (ecc.count == 0) revert TxNotFound(account, txHash);

        try semaphore.validateProof(groupId, proof) {
            ecc.count += 1;
            emit SignedTx(account, txHash);

            // execute the transaction if condition allows
            if (execute && ecc.count >= thresholds[account]) executeTx(txHash);
        } catch Error(string memory reason) {
            revert InvalidSemaphoreProof(bytes(reason));
        } catch (bytes memory reason) {
            revert InvalidSemaphoreProof(reason);
        }
    }

    function executeTx(bytes32 txHash)
        public
        virtual
        moduleInstalled
        returns (bytes memory returnData)
    {
        // retrieve the group ID
        address account = msg.sender;
        uint8 threshold = thresholds[account];
        ExtCallCount storage ecc = acctTxCount[account][txHash];

        if (ecc.count == 0) revert TxNotFound(account, txHash);
        if (ecc.count < threshold) revert ThresholdNotReach(account, threshold, ecc.count);

        // Execute the transaction on the owned account
        returnData = IERC7579Account(account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(), abi.encodePacked(ecc.targetAddr, ecc.value, ecc.callData)
        )[0];

        emit ExecutedTx(account, txHash);

        // Clean up the storage
        delete acctTxCount[account][txHash];
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
        return SEMAPHORE_EXECUTOR;
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return VERSION;
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
