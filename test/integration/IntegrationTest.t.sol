// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ModuleKitHelpers, UserOpData } from "modulekit/ModuleKit.sol";

import { ISemaphore } from "src/interfaces/Semaphore.sol";
import { ExtCallCount, SemaphoreExecutor } from "src/SemaphoreExecutor.sol";

import { Identity, IdentityLib, SimpleContract } from "test/utils/TestUtils.sol";
import { SharedTestSetup } from "test/utils/SharedTestSetup.sol";
import { NUM_MEMBERS } from "test/utils/Constants.sol";

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
    function test_balanceTransfer_SingleMember_InitiateTx()
        public
        setupSmartAcctWithMembersThreshold(1, 1)
    {
        Identity signer = $users[0].identity;
        address receiver = $users[1].addr;
        uint256 value = 1 ether;
        uint256 seq = 0;

        uint256 senderBefore = smartAcct.account.balance;
        uint256 receiverBefore = receiver.balance;

        (UserOpData memory userOpData, bytes32 txHash) =
            _setupInitiateTx(signer, receiver, value, "", true);

        // Test: expect to have call InitiateTx() and executeTx()
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.InitiatedTx(smartAcct.account, seq, txHash);
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ExecutedTx(smartAcct.account, txHash);

        userOpData.execUserOps();

        // Test: user balance has updated
        uint256 senderAfter = smartAcct.account.balance;
        uint256 receiverAfter = receiver.balance;

        assertEq(
            receiverAfter - receiverBefore,
            value,
            "test_balanceTransfer_SingleMember_InitiateTx_receiverBalance"
        );
        assertApproxEqRel(
            senderBefore - senderAfter,
            value,
            0.001e18,
            "test_balanceTransfer_SingleMember_InitiateTx_senderBalance"
        );
    }

    function test_txCall_MultiMembers_InitiateTx_SignTx_ExecuteTx()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 2)
        deploySimpleContract
    {
        Identity signer1 = $users[0].identity;
        Identity signer2 = $users[1].identity;
        Identity signer3 = $users[2].identity;
        uint256 value = 1 ether;
        uint256 newVal = 8964;
        uint256 gId = 0;
        uint256 seq = 0;
        uint256 senderBefore = smartAcct.account.balance;
        address target = address(simpleContract);
        bytes memory callData = abi.encodeCall(SimpleContract.setVal, (newVal));

        /**
         *  Perform 1: initiate a transaction
         */
        (UserOpData memory userOpData1, bytes32 txHash) =
            _setupInitiateTx(signer1, target, value, callData, false);

        // Test: expected event emitted
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.InitiatedTx(smartAcct.account, seq, txHash);

        userOpData1.execUserOps();

        // Test: the internal state of SemaphoreExecutor
        ExtCallCount memory ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);
        assertEq(ecc.targetAddr, target);
        assertEq(ecc.callData, callData);
        assertEq(ecc.value, value);
        assertEq(ecc.count, 1);

        /**
         *  Perform 2: Another signer signs the transaction
         */

        // Compose a Semaphore proof
        ISemaphore.SemaphoreProof memory smProof2 =
            signer2.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        // Compose UserOpData
        UserOpData memory userOpData2 = _getSemaphoreUserOpData(
            signer2, 0, abi.encodeCall(SemaphoreExecutor.signTx, (txHash, smProof2, false))
        );

        // Test: expected event emitted
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.SignedTx(smartAcct.account, txHash);

        userOpData2.execUserOps();

        // Test: the internal state of SemaphoreExecutor
        ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);
        assertEq(ecc.count, 2);

        /**
         *  Perform 3: The 3rd user executes the transaction
         */

        // Compose UserOpData
        UserOpData memory userOpData3 = _getSemaphoreUserOpData(
            signer3, 0, abi.encodeCall(SemaphoreExecutor.executeTx, (txHash))
        );

        // Test: expected event emitted
        vm.expectEmit(true, true, true, true);
        emit SimpleContract.ValueSet(smartAcct.account, value, newVal);
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ExecutedTx(smartAcct.account, txHash);

        userOpData3.execUserOps();

        // Test: the internal state of SemaphoreExecutor
        assertEq(
            simpleContract.val(),
            newVal,
            "test_txCall_MultiMembers_InitiateTx_SignTx_ExecuteTx_newVal"
        );
        assertEq(
            address(simpleContract).balance,
            value,
            "test_txCall_MultiMembers_InitiateTx_SignTx_ExecuteTx_receiverBalance"
        );

        uint256 senderAfter = smartAcct.account.balance;
        assertApproxEqRel(
            senderBefore - senderAfter,
            value,
            0.001e18,
            "test_txCall_MultiMembers_InitiateTx_SignTx_ExecuteTx_senderBalance"
        );
    }
}
