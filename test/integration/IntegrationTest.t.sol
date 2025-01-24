// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// forge-std
import { Test } from "forge-std/Test.sol";
// import { console } from "forge-std/console.sol";

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
    /**
     * Tests
     */
    // function test_initiateTransferInvalidSignature()
    //     public
    //     setupSmartAcctWithMembersThreshold(1, 1)
    // {
    //     User storage member = $users[0];
    //     User storage recipient = $users[1];
    //     UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
    //         member.identity,
    //         abi.encodeCall(
    //             SemaphoreMSAValidator.initiateTx,
    //             (recipient.addr, "", getEmptySemaphoreProof(), false)
    //         ),
    //         1 ether
    //     );
    //     userOpData.userOp.signature[0] = hex"ff";
    //     userOpData.userOp.signature[1] = hex"ff";

    //     smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSignature.selector);
    //     userOpData.execUserOps();
    // }

    // function test_initiateTransferInvalidSemaphoreProof()
    //     public
    //     setupSmartAcctWithMembersThreshold(1, 1)
    // {
    //     User storage member = $users[0];
    //     User storage recipient = $users[1];
    //     UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
    //         member.identity,
    //         abi.encodeCall(
    //             SemaphoreMSAValidator.initiateTx,
    //             (recipient.addr, "", getEmptySemaphoreProof(), false)
    //         ),
    //         1 ether
    //     );

    //     smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSemaphoreProof.selector);
    //     userOpData.execUserOps();
    // }

    // function test_initiateTransferSingleMember() public {
    //     uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);

    //     (bytes32 txHash, address targetAddr, uint256 value) = _setupInitiateTransferSingleMember();

    //     // Test the states are changed accordingly
    //     assertEq(semaphoreValidator.acctSeqNum(smartAcct.account), seq + 1);

    //     (address eccTargetAddr, bytes memory eccCallData, uint256 eccValue, uint8 eccCount) =
    //         semaphoreValidator.acctTxCount(smartAcct.account, txHash);

    //     assertEq(eccTargetAddr, targetAddr);
    //     assertEq(eccValue, value);
    //     assertEq(eccCallData, "");
    //     assertEq(eccCount, 1);
    // }

    // function test_initiateTransferSingleMemberExecuteInvalidTxHash() public {
    //     (bytes32 forgedHash,,) = _setupInitiateTransferSingleMember();
    //     // Changed the last 2 bytes to 0xffff
    //     forgedHash |= bytes32(uint256(0xffff));

    //     User storage member = $users[0];

    //     UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
    //         member.identity, abi.encodeCall(SemaphoreMSAValidator.executeTx, (forgedHash)), 0
    //     );

    //     smartAcct.expect4337Revert(
    //         abi.encodeWithSelector(
    //             SemaphoreMSAValidator.TxHashNotFound.selector, smartAcct.account, forgedHash
    //         )
    //     );
    //     userOpData.execUserOps();
    // }

    // function test_initiateTransferSingleMemberExecute() public {
    //     User storage member = $users[0];
    //     (bytes32 txHash, address targetAddr, uint256 value) = _setupInitiateTransferSingleMember();
    //     uint256 beforeBalance = targetAddr.balance;

    //     UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
    //         member.identity, abi.encodeCall(SemaphoreMSAValidator.executeTx, (txHash)), 0
    //     );

    //     // Test event emission
    //     vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);
    //     userOpData.execUserOps();

    //     uint256 afterBalance = targetAddr.balance;
    //     assertEq(afterBalance - beforeBalance, value);
    // }

    // function test_initiateTransferSingleMemberExecuteCombined() public {
    //     address recipientAddr = $users[1].addr;
    //     uint256 beforeBalance = recipientAddr.balance;
    //     (, address targetAddr, uint256 value) = _setupInitiateTransferSingleMember(true, true);

    //     // Test: user balance has updated
    //     assert(recipientAddr == targetAddr);
    //     uint256 afterBalance = targetAddr.balance;
    //     assertEq(afterBalance - beforeBalance, value);
    // }

    // function test_initiateTxSingleMemberInvalidTargetAddress()
    //     public
    //     setupSmartAcctWithMembersThreshold(1, 1)
    //     deploySimpleContract
    // {
    //     User storage member = $users[0];
    //     uint256 testVal = 7;

    //     // Test: non-validator target is disallowed
    //     UserOpData memory userOpData = smartAcct.getExecOps({
    //         target: address(simpleContract),
    //         value: 0,
    //         callData: abi.encodeCall(SimpleContract.setVal, (testVal)),
    //         txValidator: address(semaphoreValidator)
    //     });
    //     userOpData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e7), uint128(2e7)));
    //     userOpData.userOpHash = smartAcct.aux.entrypoint.getUserOpHash(userOpData.userOp);
    //     userOpData.userOp.signature = member.identity.signHash(userOpData.userOpHash);

    //     smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidTargetAddress.selector);
    //     userOpData.execUserOps();
    // }

    // function test_initiateTxSingleMemberSignExecuteTx() public {
    //     uint256 testVal = 7;
    //     bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));

    //     (UserOpData memory userOpData, bytes32 txHash) =
    //         _setupInitiateTxSingleMember(txCallData, true);

    //     uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);

    //     vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     emit SemaphoreMSAValidator.InitiatedTx(smartAcct.account, seq, txHash);
    //     vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);
    //     userOpData.execUserOps();

    //     // Test: the deployed contract value is updated
    //     assertEq(simpleContract.val(), testVal);
    // }

    // function test_initiateTxSingleMemberInvalidExecuteTx() public {
    //     uint256 testVal = 7;
    //     bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
    //     // Invalidate the txCallData
    //     txCallData[0] = hex"ff";
    //     txCallData[1] = hex"ff";

    //     (UserOpData memory userOpData,) = _setupInitiateTxSingleMember(txCallData, true);

    //     // Expect ExecuteTxFailure error
    //     smartAcct.expect4337Revert(SemaphoreMSAValidator.ExecuteTxFailure.selector);
    //     userOpData.execUserOps();
    // }

    // function test_initiateTxMultiMembersCannotDoubleSign() public {
    //     uint256 testVal = 7;
    //     bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
    //     (UserOpData memory userOpData, bytes32 txHash) =
    //         _setupInitiateTxMultiMembers(txCallData, 0, true);
    //     userOpData.execUserOps();

    //     User storage doubleSigner = $users[0];
    //     (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
    //     ISemaphore.SemaphoreProof memory smProof = doubleSigner.identity.generateSempahoreProof(
    //         groupId, _getMemberCmts(MEMBER_NUM), txHash
    //     );

    //     // Composing the UserOpData
    //     UserOpData memory userOpData2 = _getSemaphoreValidatorUserOpData(
    //         doubleSigner.identity,
    //         abi.encodeCall(SemaphoreMSAValidator.signTx, (txHash, smProof, true)),
    //         0
    //     );

    //     smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSemaphoreProof.selector);
    //     userOpData2.execUserOps();
    // }

    // function test_initiateTxMultiMembersSignTx() public {
    //     uint256 testVal = 7;
    //     bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
    //     (UserOpData memory userOpData, bytes32 txHash) =
    //         _setupInitiateTxMultiMembers(txCallData, 0, true);
    //     userOpData.execUserOps();

    //     User storage anotherSigner = $users[1];
    //     (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
    //     ISemaphore.SemaphoreProof memory smProof = anotherSigner.identity.generateSempahoreProof(
    //         groupId, _getMemberCmts(MEMBER_NUM), txHash
    //     );

    //     // Composing the UserOpData
    //     UserOpData memory userOpData2 = _getSemaphoreValidatorUserOpData(
    //         anotherSigner.identity,
    //         abi.encodeCall(SemaphoreMSAValidator.signTx, (txHash, smProof, false)),
    //         0
    //     );

    //     // Expect SignedTx event
    //     vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     emit SemaphoreMSAValidator.SignedTx(smartAcct.account, txHash);
    //     userOpData2.execUserOps();

    //     // Check the state
    //     (,,, uint8 eccCount) = semaphoreValidator.acctTxCount(smartAcct.account, txHash);
    //     assertEq(eccCount, 2);
    // }

    // function test_initiateTxMultiMembersSignExecuteTx() public {
    //     uint256 newVal = 7;
    //     uint256 msgVal = 100;

    //     bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (newVal));
    //     (UserOpData memory userOpData, bytes32 txHash) =
    //         _setupValExeInitiateTxMultiMembers(txCallData, msgVal, true);
    //     userOpData.execUserOps();

    //     User storage recipient = $users[2];

    //     User storage anotherSigner = $users[1];
    //     (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
    //     ISemaphore.SemaphoreProof memory smProof = anotherSigner.identity.generateSempahoreProof(
    //         groupId, _getMemberCmts(MEMBER_NUM), txHash
    //     );

    //     // Composing the UserOpData
    //     UserOpData memory userOpData2 = _getSemaphoreValExeUserOpData(
    //         anotherSigner.identity,
    //         // abi.encodeCall(SemaphoreMSAExecutor.executeTx, (txHash, smProof, true)),
    //         abi.encodeCall(SemaphoreMSAExecutor.executeTx, (recipient.addr, msgVal, hex"")),
    //         0
    //     );

    //     // Expect SignedTx, ValueSet, and ExecuteTx events
    //     // vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     // emit SemaphoreMSAValidator.SignedTx(smartAcct.account, txHash);

    //     // vm.expectEmit(true, true, true, true, address(simpleContract));
    //     // emit SimpleContract.ValueSet(smartAcct.account, msgVal, newVal);

    //     // vm.expectEmit(true, true, true, true, address(semaphoreValidator));
    //     // emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);

    //     userOpData2.execUserOps();

    //     // Check the state
    //     // assertEq(simpleContract.val(), newVal);
    // }
}
