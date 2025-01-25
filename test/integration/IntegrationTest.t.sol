// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console } from "forge-std/console.sol";

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR,
    VALIDATION_SUCCESS
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// Semaphore
import { ISemaphore, ISemaphoreVerifier } from "src/interfaces/Semaphore.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { Semaphore } from "semaphore/Semaphore.sol";

import { SemaphoreValidator, ERC7579ValidatorBase } from "src/SemaphoreValidator.sol";
import { SemaphoreExecutor, ERC7579ExecutorBase } from "src/SemaphoreExecutor.sol";

import { LibSort, LibString } from "solady/Milady.sol";
import {
    getEmptyUserOperation,
    getEmptySemaphoreProof,
    getGroupRmMerkleProof,
    getTestUserOpCallData,
    Identity,
    IdentityLib,
    SimpleContract
} from "test/utils/TestUtils.sol";
import { SharedTestSetup, User } from "test/utils/SharedTestSetup.sol";

contract IntegrationTest is SharedTestSetup {
    using ModuleKitHelpers for *;
    using IdentityLib for Identity;

    /**
     * Internal helper funcitons
     */
    function _getSemaphoreUserOpData(
        Identity signer,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = smartAcct.getExecOps({
            target: address(semaphoreExecutor),
            value: value,
            callData: callData,
            txValidator: address(semaphoreValidator)
        });

        // We need to increase the accountGasLimits, default 2e6 is not enough to verify
        // signature, for all those elliptic curve computation.
        // Encoding two fields here, validation and execution gas
        userOpData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e7), uint128(2e7)));
        userOpData.userOpHash = smartAcct.aux.entrypoint.getUserOpHash(userOpData.userOp);
        userOpData.userOp.signature = signer.signHash(userOpData.userOpHash);
    }

    function _setupInitiateTx(
        Identity signer,
        address target,
        uint256 value,
        bytes memory txCallData,
        bool bExecute
    )
        internal
        returns (UserOpData memory userOpData, bytes32 txHash)
    {
        // Compose txHash
        uint256 seq = semaphoreExecutor.getAcctSeqNum(smartAcct.account);
        txHash = keccak256(abi.encodePacked(seq, target, value, txCallData));

        // Compose Semaphore proof
        (, uint256 groupId) = semaphoreExecutor.getGroupId(smartAcct.account);
        uint8 memberCnt = semaphoreExecutor.memberCount(smartAcct.account);
        ISemaphore.SemaphoreProof memory smProof =
            signer.getSempahoreProof(groupId, _getMemberCmts(memberCnt), txHash);

        // Compose UserOpData
        userOpData = _getSemaphoreUserOpData(
            signer,
            value,
            abi.encodeCall(SemaphoreExecutor.initiateTx, (target, txCallData, smProof, bExecute))
        );
    }

    /**
     * Tests
     */
    function test_balanceTransfer_SingleMember_InitiateTx() public setupSmartAcctWithMembersThreshold(1, 1) {
        Identity signer = $users[0].identity;
        address receiver = $users[1].addr;
        uint256 value = 1 ether;
        uint256 seq = 0;

        uint256 senderBefore = smartAcct.account.balance;
        uint256 receiverBefore = receiver.balance;

        (UserOpData memory userOpData, bytes32 txHash) = _setupInitiateTx(signer, receiver, value, "", true);

        // Test: expect to have call InitiateTx() and executeTx()
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.InitiatedTx(smartAcct.account, seq, txHash);
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ExecutedTx(smartAcct.account, txHash);

        userOpData.execUserOps();

        // Test: user balance has updated
        uint256 senderAfter = smartAcct.account.balance;
        uint256 receiverAfter = receiver.balance;

        assertEq(senderAfter - senderBefore, value, "test_balanceTransfer_SingleMember_InitiateTx_senderBalance");
        assertGe(receiverBefore - receiverAfter, value, "test_balanceTransfer_SingleMember_InitiateTx_receiverBalance");
    }

    function test_txCall_MultiMembers_InitiateTx_SignTx_ExecuteTx() public { }
}
