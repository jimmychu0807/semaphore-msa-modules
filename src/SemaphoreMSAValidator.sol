// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone module-kit
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/ModuleKit.sol";

import { ISemaphoreMSAExecutor } from "src/interfaces/ISemaphoreMSAExecutor.sol";
import { Identity } from "src/utils/Identity.sol";
import { SIGNATURE_LEN } from "src/utils/Constants.sol";
// import { console } from "forge-std/console.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    /**
     * Errors
     */
    error InvalidSignature(address account, bytes signature);
    error InvalidTargetAddress(address account, address target);
    error MemberNotExists(address account, uint256 cmt);
    error NoSemaphoreModuleInstalled(address account);

    /**
     * Events
     */
    event SemaphoreMSAValidatorInitialized(address indexed account);
    event SemaphoreMSAValidatorUninitialized(address indexed account);

    /**
     * Storage
     */
    ISemaphoreMSAExecutor public semaphoreExecutor;
    mapping(address account => bool installed) public acctInstalled;

    // Ensure the following match with the 3 function calls.
    bytes4[3] public ALLOWED_SELECTORS = [
        semaphoreExecutor.initiateTx.selector,
        semaphoreExecutor.signTx.selector,
        semaphoreExecutor.executeTx.selector
    ];

    constructor(ISemaphoreMSAExecutor _semaphoreExecutor) {
        semaphoreExecutor = _semaphoreExecutor;
    }

    modifier moduleInstalled() {
        if (!acctInstalled[msg.sender]) revert NotInitialized(msg.sender);
        _;
    }

    /**
     * Config
     */
    function isInitialized(address account) external view override returns (bool) {
        return acctInstalled[account];
    }

    function onInstall(bytes calldata) external override {
        address account = msg.sender;
        acctInstalled[account] = true;

        emit SemaphoreMSAValidatorInitialized(account);
    }

    function onUninstall(bytes calldata) external override moduleInstalled {
        // remove from our data structure
        address account = msg.sender;
        delete acctInstalled[account];

        emit SemaphoreMSAValidatorUninitialized(account);
    }

    /**
     * Module logics
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
        if (signature.length != SIGNATURE_LEN || !Identity.verifySignature(hash, signature)) {
            revert InvalidSignature(account, signature);
        }

        // Verify if the identity commitment is one of the semaphore group members
        bytes memory pubKey = signature[0:64];
        uint256 cmt = Identity.getCommitment(pubKey);
        if (!semaphoreExecutor.accountHasMember(account, cmt)) revert MemberNotExists(account, cmt);

        // We don't allow call to other contracts, other than msa-validator and msa-executor
        // quick hack here
        (address target,, bytes4 funcSel) = abi.decode(targetCallData, (address, uint256, bytes4));
        if (target != address(semaphoreExecutor)) revert InvalidTargetAddress(account, target);

        // We only allow calls to `initiateTx()`, `signTx()`, and `executeTx()` to pass,
        //   and reject the rest.
        return _isAllowedSelector(funcSel);
    }

    function _isAllowedSelector(bytes4 sel) internal view returns (bool allowed) {
        for (uint256 i = 0; i < ALLOWED_SELECTORS.length; ++i) {
            if (sel == ALLOWED_SELECTORS[i]) return true;
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
