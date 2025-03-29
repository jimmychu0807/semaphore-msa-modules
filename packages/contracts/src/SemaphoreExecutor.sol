// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone module-kit
import { IERC7579Account } from "modulekit/Accounts.sol";
import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";

import { LibBytes, LibSort } from "solady/Milady.sol";
import { ISemaphore, ISemaphoreGroups } from "src/interfaces/Semaphore.sol";
import { ISemaphoreValidator } from "src/interfaces/ISemaphoreValidator.sol";
import { ISemaphoreExecutor } from "src/interfaces/ISemaphoreExecutor.sol";
import {
    CMT_BYTELEN,
    MAX_MEMBERS,
    SEMAPHORE_VALIDATOR_NAME,
    SEMAPHORE_EXECUTOR_NAME,
    VERSION
} from "src/utils/Constants.sol";
import { SentinelList4337Bytes32Lib, SENTINEL } from "sentinellist/SentinelList4337Bytes32.sol";

struct ExtCallCount {
    address targetAddr;
    bytes callData;
    uint256 value;
    uint8 count;
}

contract SemaphoreExecutor is ISemaphoreExecutor, ERC7579ExecutorBase {
    using LibSort for *;
    using SentinelList4337Bytes32Lib for SentinelList4337Bytes32Lib.SentinelList;

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
    event AddedMembers(address indexed, uint8 indexed length);
    event RemovedMember(address indexed, uint256 indexed commitment);
    event ThresholdSet(address indexed account, uint8 indexed threshold);
    event InitiatedTx(address indexed account, uint256 indexed seq, bytes32 indexed txHash);
    event SignedTx(address indexed account, bytes32 indexed txHash);
    event ExecutedTx(address indexed account, bytes32 indexed txHash);

    /**
     * Storage
     */
    ISemaphore public immutable SEMAPHORE;
    ISemaphoreGroups public immutable GROUPS;
    address public semaphoreValidatorAddr;

    mapping(address account => uint256 groupId) public groupMapping;
    mapping(address account => uint8 threshold) public thresholds;
    SentinelList4337Bytes32Lib.SentinelList private acctMembers;

    // smart account -> txHash -> valid proof count
    mapping(address account => mapping(bytes32 txHash => ExtCallCount callDataCount)) public
        acctTxCount;

    // keep track of seqNum of txs that require threshold signature
    mapping(address account => uint256 seqNum) public acctSeqNum;

    constructor(ISemaphore _semaphore) {
        SEMAPHORE = _semaphore;
        GROUPS = ISemaphoreGroups(address(_semaphore));
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
        bytes calldata cmtBytes = data[1:dataLen];
        uint256[] memory cmts = _convertToCmts(cmtBytes);

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

        uint256 groupId = SEMAPHORE.createGroup();
        groupMapping[account] = groupId;

        // Add members to the group
        SEMAPHORE.addMembers(groupId, cmts);
        acctMembers.init(account);
        for (uint256 i = 0; i < cmts.length; i++) {
            acctMembers.push(account, bytes32(cmts[i]));
        }

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
        acctMembers.popAll(account);

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

    function accountMemberCount(address account) public view returns (uint8) {
        (bytes32[] memory entries,) =
            acctMembers.getEntriesPaginated(account, SENTINEL, MAX_MEMBERS);
        return uint8(entries.length);
    }

    function accountHasMember(address account, uint256 cmt) external view returns (bool) {
        return acctMembers.contains(account, bytes32(cmt));
    }

    /**
     * Set-once Functions
     */
    function setSemaphoreValidator(address target) external {
        if (semaphoreValidatorAddr != address(0)) revert SemaphoreValidatorSetAlready();

        ISemaphoreValidator val = ISemaphoreValidator(target);
        if (
            !LibBytes.eq(bytes(val.name()), bytes(SEMAPHORE_VALIDATOR_NAME))
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
        uint8 memberCount = accountMemberCount(account);

        if (newThreshold == 0 || newThreshold > memberCount) {
            revert InvalidThreshold(account);
        }

        thresholds[account] = newThreshold;
        emit ThresholdSet(account, newThreshold);
    }

    function addMembers(uint256[] calldata cmts) external moduleInstalled {
        address account = msg.sender;
        uint256 groupId = groupMapping[account];
        uint8 memberCount = accountMemberCount(account);

        if (memberCount + cmts.length > MAX_MEMBERS) revert MaxMemberReached(account);

        for (uint256 i = 0; i < cmts.length; ++i) {
            if (cmts[i] == uint256(0)) revert InvalidCommitment(account);
            if (GROUPS.hasMember(groupId, cmts[i])) revert IsMemberAlready(account, cmts[i]);
        }

        SEMAPHORE.addMembers(groupId, cmts);
        for (uint256 i = 0; i < cmts.length; i++) {
            acctMembers.push(account, bytes32(cmts[i]));
        }

        emit AddedMembers(account, uint8(cmts.length));
    }

    function removeMember(
        uint256 prevCmt,
        uint256 cmt,
        uint256[] calldata merkleProofSiblings
    )
        external
        moduleInstalled
    {
        address account = msg.sender;
        uint8 memberCount = accountMemberCount(account);

        if (memberCount == thresholds[account]) revert MemberCntReachesThreshold(account);

        uint256 groupId = groupMapping[account];
        if (!GROUPS.hasMember(groupId, cmt)) revert MemberNotExists(account, cmt);

        acctMembers.pop(account, bytes32(prevCmt), bytes32(cmt));
        SEMAPHORE.removeMember(groupId, cmt, merkleProofSiblings);

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
        try SEMAPHORE.validateProof(groupId, proof) {
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

        try SEMAPHORE.validateProof(groupId, proof) {
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

    /**
     * Internal helper functions
     */
    function _convertToCmts(bytes calldata cmtBytes)
        internal
        pure
        returns (uint256[] memory cmts)
    {
        uint256 cmtNum = cmtBytes.length / CMT_BYTELEN;

        cmts = new uint256[](cmtNum);
        for (uint256 i = 0; i < cmtNum; i++) {
            cmts[i] = uint256(bytes32(cmtBytes[i * CMT_BYTELEN:(i + 1) * CMT_BYTELEN]));
        }
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
        return SEMAPHORE_EXECUTOR_NAME;
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
