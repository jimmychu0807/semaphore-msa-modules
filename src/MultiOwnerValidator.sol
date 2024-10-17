// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract MultiOwnerValidator is ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/
    mapping(uint256 ownerId => mapping(address account => address)) public owners;
    mapping(address account => uint256) public ownerCount;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        owners[0][msg.sender] = address(uint160(bytes20(data)));
        ownerCount[msg.sender] = 1;
    }

    /**
     * De-initialize the module with the given data
     *
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        uint256 _ownerCount = ownerCount[msg.sender];
        for (uint256 i = 0; i < _ownerCount; i++) {
            delete owners[i][msg.sender];
        }
        delete ownerCount[msg.sender];
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return ownerCount[smartAccount] > 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Validates PackedUserOperation
     *
     * @param userOp UserOperation to be validated
     * @param userOpHash Hash of the UserOperation to be validated
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - 0 if the signature is valid
     *  - 1 if the signature is invalid
     *  - <20-byte> aggregatorOrSigFail, <6-byte> validUntil and <6-byte> validAfter (see ERC-4337
     * for more details)
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
        (uint256 _ownerId, bytes memory _signature) = abi.decode(userOp.signature, (uint256, bytes));
        bool validSig = owners[_ownerId][msg.sender].isValidSignatureNow(ECDSA.toEthSignedMessageHash(userOpHash), _signature);

        return _packValidationData(!validSig, type(uint48).max, 0);
    }

    /**
     * Validates an ERC-1271 signature
     *
     * @param sender The sender of the ERC-1271 call to the account
     * @param hash The hash of the message
     * @param signature The signature of the message
     *
     * @return sigValidationResult the result of the signature validation, which can be:
     *  - EIP1271_SUCCESS if the signature is valid
     *  - EIP1271_FAILED if the signature is invalid
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sigValidationResult)
    {
        (uint256 _ownerId, bytes memory _signature) = abi.decode(signature, (uint256, bytes));
        address owner = owners[_ownerId][msg.sender];
        address recover = ECDSA.recover(hash, _signature);
        bool valid = SignatureCheckerLib.isValidSignatureNow(owner, hash, _signature);
        return SignatureCheckerLib.isValidSignatureNow(owner, hash, _signature)
            ? EIP1271_SUCCESS
            : EIP1271_FAILED;
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

    function addOwner(uint256 ownerId, address owner) external {
        require(owners[ownerId][msg.sender] == address(0), "Owner already exists");
        owners[ownerId][msg.sender] = owner;
        ownerCount[msg.sender]++;
    }

    function removeOwner(uint256 ownerId) external {
        delete owners[ownerId][msg.sender];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "MultiOwnerValidator";
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
