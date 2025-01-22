// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone module-kit
import { IERC7579Account } from "modulekit/Accounts.sol";
import { ERC7579ValidatorBase, ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/ModuleKit.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";

import { LibSort } from "solady/Milady.sol";

import { ISemaphore, ISemaphoreGroups } from "./utils/Semaphore.sol";
import { ValidatorLibBytes } from "./utils/ValidatorLibBytes.sol";
import { Identity } from "./utils/Identity.sol";
import { console } from "forge-std/console.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase, ERC7579ExecutorBase {
    using LibSort for *;
    using ValidatorLibBytes for bytes;

    // Constants
    uint8 public constant MAX_MEMBERS = 32;
    uint8 public constant CMT_BYTELEN = 32;

    // Ensure the following match with the 3 function calls.
    bytes4[3] public ALLOWED_SELECTORS =
        [this.initiateTx.selector, this.signTx.selector, this.executeTx.selector];

    struct ExtCallCount {
        address targetAddr;
        bytes callData;
        uint256 value;
        uint8 count;
    }

    /**
     * Errors
     */
    error MemberCntReachesThreshold(address account);
    error InvalidCommitment(address account);
    error InvalidThreshold(address account);
    error MaxMemberReached(address account);
    error CommitmentsNotUnique();
    error MemberNotExists(address account, uint256 cmt);
    error IsMemberAlready(address acount, uint256 cmt);
    error TxHasBeenInitiated(address account, bytes32 txHash);
    error TxHashNotFound(address account, bytes32 txHash);
    error ThresholdNotReach(address account, uint8 threshold, uint8 current);
    error InvalidInstallData();
    error InvalidSignatureLen(address account, uint256 len);
    error InvalidSignature(address account, bytes signature);
    error InvalidSemaphoreProof(bytes reason);
    error NonValidatorCallBanned(address targetAddr, address selfAddr);
    error InitiateTxWithNullAddress(address account);
    error InitiateTxWithNullCallDataAndNullValue(address account, address targetAddr);
    error ExecuteTxFailure(address account, address targetAddr, uint256 value, bytes callData);

    /**
     * Events
     */
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);
    event AddedMembers(address indexed, uint256 indexed length);
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
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data

        // Ensure the module isn't installed already for the smart account
        address account = msg.sender;
        if (thresholds[account] > 0) revert AlreadyInitialized(account);

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

        emit ModuleInitialized(account);
    }

    function onUninstall(bytes calldata) external override moduleInstalled {
        // remove from our data structure
        address account = msg.sender;
        delete thresholds[account];
        delete groupMapping[account];
        delete acctSeqNum[account];
        delete memberCount[account];

        //TODO: what is a good way to delete entries associated with `acctTxCount[account]`,
        //   The following line will make the compiler fail.
        // delete acctTxCount[account];

        emit ModuleUninitialized(account);
    }

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
        memberCount[account] += uint8(cmts.length);

        emit AddedMembers(account, cmts.length);
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

    function getAcctSeqNum(address account) external view returns (uint256) {
        return acctSeqNum[account];
    }

    function getGroupId(address account) external view returns (bool, uint256) {
        uint256 groupId = groupMapping[account];
        if (thresholds[account] == 0) return (false, 0);
        return (true, groupId);
    }

    function initiateTx(
        address targetAddr,
        bytes calldata txCallData,
        ISemaphore.SemaphoreProof calldata proof,
        bool execute
    )
        external
        payable
        moduleInstalled
        returns (bytes32 txHash)
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        // Check:
        //   1. targetAddr cannot be 0
        //   2. if txCallData is blank, then msg.value must be > 0, else revert
        if (targetAddr == address(0)) revert InitiateTxWithNullAddress(account);
        if (txCallData.length == 0 && msg.value == 0) {
            revert InitiateTxWithNullCallDataAndNullValue(account, targetAddr);
        }

        // By this point, txParams should be validated.
        // combine the txParams with the account nonce and compute its hash
        uint256 seq = acctSeqNum[account];
        txHash = keccak256(abi.encodePacked(seq, targetAddr, msg.value, txCallData));

        ExtCallCount storage ecc = acctTxCount[account][txHash];
        if (ecc.count != 0) revert TxHasBeenInitiated(account, txHash);

        // finally, check semaphore proof
        try semaphore.validateProof(groupId, proof) {
            // By this point, the proof also passed semaphore check. Start writing to the storage
            acctSeqNum[account] += 1;
            ecc.targetAddr = targetAddr;
            ecc.callData = txCallData;
            ecc.value = msg.value;
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
        moduleInstalled
    {
        // retrieve the group ID
        address account = msg.sender;
        uint256 groupId = groupMapping[account];

        console.log("signTx");
        console.logBytes32(txHash);

        // Check if the txHash exist
        ExtCallCount storage ecc = acctTxCount[account][txHash];
        if (ecc.count == 0) revert TxHashNotFound(account, txHash);

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

    function executeTx(bytes32 txHash) public moduleInstalled returns (bytes[] memory returnData) {
        // retrieve the group ID
        address account = msg.sender;
        uint8 threshold = thresholds[account];
        ExtCallCount storage ecc = acctTxCount[account][txHash];

        if (ecc.count == 0) revert TxHashNotFound(account, txHash);
        if (ecc.count < threshold) revert ThresholdNotReach(account, threshold, ecc.count);

        // TODO: Review if there a better way to make external contract call given the
        // target address, value, and call data.
        //
        // address payable targetAddr = payable(ecc.targetAddr);
        // (bool success, bytes memory returnData) = targetAddr.call{ value: ecc.value }(ecc.callData);
        // if (!success) revert ExecuteTxFailure(account, targetAddr, ecc.value, ecc.callData);

        console.log("before executeTx");
        console.logBytes32(txHash);

        // Execute the transaction on the owned account
        returnData = IERC7579Account(account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            abi.encodePacked(ecc.targetAddr, ecc.value, ecc.callData)
        );

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
        virtual
        override
        returns (ValidationData)
    {
        address account = userOp.sender;
        bytes calldata targetCallData = userOp.callData[100:];
        if (_validateSignatureWithConfig(account, userOpHash, userOp.signature, targetCallData)) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
    }

    /**
     * Validates an ERC-1271 signature with the sender
     *
     * @param hash bytes32 hash of the data
     * @param data bytes data containing the signatures, and target calldata
     *
     * @return bytes4 EIP1271_SUCCESS if the signature is valid, EIP1271_FAILED otherwise
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        bytes calldata signature = data[0:160];
        bytes calldata targetCallData = data[160:];
        if (_validateSignatureWithConfig(sender, hash, signature, targetCallData)) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _isAllowedSelector(bytes4 sel) internal view returns (bool allowed) {
        for (uint256 i = 0; i < ALLOWED_SELECTORS.length; ++i) {
            if (sel == ALLOWED_SELECTORS[i]) return true;
        }
        return false;
    }

    function _validateSignatureWithConfig(
        address account,
        bytes32 hash,
        bytes calldata signature,
        bytes calldata targetCallData
    )
        internal
        view
        returns (bool)
    {
        // you want to exclude initiateTx, signTx, executeTx from needing tx count.
        // you just need to ensure they are a valid proof from the semaphore group members
        uint256 groupId = groupMapping[account];

        // The userOp.signature is 160 bytes containing:
        //   (uint256 pubX (32 bytes), uint256 pubY (32 bytes), bytes[96] signature (96 bytes))
        if (signature.length != 160) {
            revert InvalidSignatureLen(account, signature.length);
        }

        // Verify signature using the public key
        if (!Identity.verifySignature(hash, signature)) {
            revert InvalidSignature(account, signature);
        }

        // Verify if the identity commitment is one of the semaphore group members
        bytes memory pubKey = signature[0:64];
        uint256 cmt = Identity.getCommitment(pubKey);
        if (!groups.hasMember(groupId, cmt)) revert MemberNotExists(account, cmt);

        // We don't allow call to other contracts.
        address targetAddr = address(bytes20(targetCallData[0:20]));
        if (targetAddr != address(this)) revert NonValidatorCallBanned(targetAddr, address(this));

        // For callData, the first 120 bytes are reserved by ERC-7579 use. Then 32 bytes of value,
        //   then the remaining as the callData passed in getExecOps
        bytes calldata valAndCallData = targetCallData[20:];
        bytes4 funcSel = bytes4(valAndCallData[32:36]);

        // We only allow calls to `initiateTx()`, `signTx()`, and `executeTx()` to pass,
        //   and reject the rest.
        return _isAllowedSelector(funcSel);
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
        return typeID == TYPE_VALIDATOR || typeID == TYPE_EXECUTOR;
    }
}
