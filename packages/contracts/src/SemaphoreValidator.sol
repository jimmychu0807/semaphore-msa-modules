// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// import { console } from "forge-std/Test.sol";

// Rhinestone module-kit
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/ModuleKit.sol";
import { LibBytes } from "solady/Milady.sol";

import { ISemaphoreExecutor } from "src/interfaces/ISemaphoreExecutor.sol";
import { Identity } from "src/utils/Identity.sol";
import {
    SIGNATURE_LEN,
    MIN_TARGET_CALLDATA_LEN,
    SEMAPHORE_EXECUTOR,
    SEMAPHORE_VALIDATOR,
    MOCK_SIG_P2,
    VERSION
} from "src/utils/Constants.sol";

contract SemaphoreValidator is ERC7579ValidatorBase {
    /**
     * Errors
     */
    error InvalidTargetAddress(address target);
    error InvalidSignature(address account, bytes signature);
    error InvalidTargetCallData(address account, bytes callData);
    error MemberNotExists(address account, bytes pubKey);
    error NoSemaphoreModuleInstalled(address account);
    error NotValidSemaphoreExecutor(address target);
    error SemaphoreExecutorNotInitialized(address account);

    /**
     * Events
     */
    event SemaphoreValidatorInitialized(address indexed account);
    event SemaphoreValidatorUninitialized(address indexed account);

    /**
     * Storage
     */
    ISemaphoreExecutor public immutable semaphoreExecutor;
    mapping(address account => bool installed) public acctInstalled;

    // Ensure the following match with the 3 function calls.
    bytes4 public constant INITIATETX_SEL = ISemaphoreExecutor.initiateTx.selector;
    bytes4 public constant SIGNTX_SEL = ISemaphoreExecutor.signTx.selector;
    bytes4 public constant EXECUTETX_SEL = ISemaphoreExecutor.executeTx.selector;

    constructor(ISemaphoreExecutor _semaphoreExecutor) {
        if (
            !LibBytes.eq(bytes(_semaphoreExecutor.name()), bytes(SEMAPHORE_EXECUTOR))
                || !_semaphoreExecutor.isModuleType(TYPE_EXECUTOR)
        ) {
            revert NotValidSemaphoreExecutor(address(_semaphoreExecutor));
        }
        semaphoreExecutor = _semaphoreExecutor;
    }

    /**
     * Config
     */
    function isInitialized(address account) external view override returns (bool) {
        return acctInstalled[account] && semaphoreExecutor.isInitialized(account);
    }

    function onInstall(bytes calldata) external override {
        address account = msg.sender;
        if (!semaphoreExecutor.isInitialized(account)) {
            revert SemaphoreExecutorNotInitialized(account);
        }

        if (acctInstalled[account]) revert ModuleAlreadyInitialized(account);

        acctInstalled[account] = true;
        emit SemaphoreValidatorInitialized(account);
    }

    function onUninstall(bytes calldata) external override {
        // remove from our data structure
        address account = msg.sender;
        if (!acctInstalled[account]) revert NotInitialized(account);

        delete acctInstalled[account];
        emit SemaphoreValidatorUninitialized(account);
    }

    /**
     * Module logics
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        public
        virtual
        override
        returns (ValidationData)
    {
        address account = userOp.sender;
        // For callData, the first 100 bytes are reserved by ERC-7579 use. Then 32 bytes of value,
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
        if (data.length < SIGNATURE_LEN) return EIP1271_FAILED;

        bytes calldata signature = data[0:SIGNATURE_LEN];
        bytes calldata targetCallData = data[SIGNATURE_LEN:];

        if (_validateSignatureWithConfig(sender, hash, signature, targetCallData)) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /**
     * Validates a signature given some data
     * For [ERC-7780](https://eips.ethereum.org/EIPS/eip-7780) Stateless Validator
     *
     * @param hash The data that was signed over
     * @param signature The signature to verify
     * @param data The data to validate the verified signature agains
     *
     * MUST validate that the signature is a valid signature of the hash
     * MUST compare the validated signature against the data provided
     * MUST return true if the signature is valid and false otherwise
     */
    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    )
        external
        view
        virtual
        returns (bool)
    {
        address account = address(bytes20(data[0:20]));
        bytes calldata targetCallData = data[20:];
        return _validateSignatureWithConfig(account, hash, signature, targetCallData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

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
        (bool found,) = semaphoreExecutor.getGroupId(account);
        if (!found) revert NoSemaphoreModuleInstalled(account);

        // The userOp.signature is 160 bytes containing:
        //   (uint256 pubX (32 bytes), uint256 pubY (32 bytes), bytes[96] signature (96 bytes))
        if (signature.length != SIGNATURE_LEN) revert InvalidSignature(account, signature);

        if (!_isMockSignature(signature) && !Identity.verifySignature(hash, signature)) {
            revert InvalidSignature(account, signature);
        }

        // Verify if the identity commitment is one of the semaphore group members
        bytes memory pubKey = signature[0:64];
        uint256 cmt = Identity.getCommitment(pubKey);
        if (!semaphoreExecutor.accountHasMember(account, cmt)) {
            revert MemberNotExists(account, pubKey);
        }

        if (targetCallData.length < MIN_TARGET_CALLDATA_LEN) {
            revert InvalidTargetCallData(account, targetCallData);
        }

        // We don't allow call to other contracts, other than msa-validator and msa-executor
        // quick hack here
        address target = address(bytes20(targetCallData[0:20]));
        bytes4 funcSel = bytes4(targetCallData[52:56]);

        if (target != address(semaphoreExecutor)) revert InvalidTargetAddress(target);

        // We only allow calls to `initiateTx()`, `signTx()`, and `executeTx()` to pass,
        //   and reject the rest.
        return _isAllowedSelector(funcSel);
    }

    function _isAllowedSelector(bytes4 sel) internal pure returns (bool) {
        return sel == INITIATETX_SEL || sel == SIGNTX_SEL || sel == EXECUTETX_SEL;
    }

    function _isMockSignature(bytes calldata signature) internal view returns (bool) {
        uint256 chainId = block.chainid;
        // Mock signature is only allowed in testnet
        uint256[4] memory allowedChains = [
            uint256(11_155_111), // sepolia
            84_532, // base sepolia
            31_337, // anvil
            11_155_420 // OP sepolia
        ];

        for (uint256 i = 0; i < allowedChains.length; ++i) {
            if (allowedChains[i] == chainId && LibBytes.eq(signature[64:], MOCK_SIG_P2)) {
                return true;
            }
        }

        return false;
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
        return SEMAPHORE_VALIDATOR;
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
        return typeID == TYPE_VALIDATOR;
    }
}
