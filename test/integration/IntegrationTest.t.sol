// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// // forge-std
// import { Test } from "forge-std/Test.sol";
// // import { console } from "forge-std/console.sol";

// // Rhinestone Modulekit
// import {
//     RhinestoneModuleKit,
//     ModuleKitHelpers,
//     AccountInstance,
//     UserOpData
// } from "modulekit/ModuleKit.sol";
// import {
//     MODULE_TYPE_EXECUTOR,
//     MODULE_TYPE_VALIDATOR,
//     VALIDATION_SUCCESS
// } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
// import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// // Semaphore
// import { ISemaphore, ISemaphoreVerifier } from "src/interfaces/Semaphore.sol";
// import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
// import { Semaphore } from "semaphore/Semaphore.sol";

// import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "src/SemaphoreMSAValidator.sol";
// import { SemaphoreMSAExecutor, ERC7579ExecutorBase } from "src/SemaphoreMSAExecutor.sol";

// import { LibSort, LibString } from "solady/Milady.sol";
// import {
//     getEmptyUserOperation,
//     getEmptySemaphoreProof,
//     getGroupRmMerkleProof,
//     getTestUserOpCallData,
//     Identity,
//     IdentityLib
// } from "test/utils/TestUtils.sol";
// import { SimpleContract } from "test/utils/SimpleContract.sol";

// struct User {
//     uint256 sk;
//     address addr;
//     Identity identity; // user commitment
// }

// uint8 constant MEMBER_NUM = 3;

// contract IntegrationTest is RhinestoneModuleKit, Test {
//     using ModuleKitHelpers for *;
//     using LibSort for *;
//     using IdentityLib for Identity;

//     AccountInstance internal smartAcct;
//     SemaphoreMSAValidator internal semaphoreValidator;
//     SemaphoreMSAExecutor internal semaphoreExecutor;
//     SimpleContract internal simpleContract;
//     User[] internal $users;

//     function setUp() public virtual {
//         // init() function comes from contract AuxiliaryFactory:
//         //   https://github.com/rhinestonewtf/modulekit/blob/main/src/test/Auxiliary.sol
//         super.init();

//         // Deploy Semaphore
//         SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
//         vm.label(address(semaphoreVerifier), "SemaphoreVerifier");
//         Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
//         vm.label(address(semaphore), "Semaphore");

//         // Create the executor
//         semaphoreExecutor = new SemaphoreMSAExecutor(semaphore);
//         vm.label(address(semaphoreValidator), "SemaphoreMSAExecutor");

//         // Create the validator
//         semaphoreValidator = new SemaphoreMSAValidator(semaphore, semaphoreExecutor);
//         vm.label(address(semaphoreValidator), "SemaphoreMSAValidator");

//         // Create three users
//         for (uint256 i = 0; i < MEMBER_NUM + 1; ++i) {
//             (address addr, uint256 sk) =
//                 makeAddrAndKey(string.concat("user", LibString.toString(i + 1)));
//             vm.deal(addr, 5 ether);
//             $users.push(User({ sk: sk, addr: addr, identity: IdentityLib.genIdentity(i + 1) }));
//         }
//     }

//     modifier setupSmartAcctWithMembersThreshold(uint8 memberNum, uint8 threshold) {
//         smartAcct = makeAccountInstance("SemaphoreMSAValidator");
//         vm.deal(smartAcct.account, 10 ether);

//         smartAcct.installModule({
//             moduleTypeId: MODULE_TYPE_VALIDATOR,
//             module: address(semaphoreValidator),
//             data: abi.encodePacked(uint8(threshold), _getMemberCmts(memberNum))
//         });
//         _;
//     }

//     modifier setupSmartAcctValExeWithMembersThreshold(uint8 memberNum, uint8 threshold) {
//         smartAcct = makeAccountInstance("SemaphoreMSAValidator");
//         vm.deal(smartAcct.account, 10 ether);

//         smartAcct.installModule({
//             moduleTypeId: MODULE_TYPE_VALIDATOR,
//             module: address(semaphoreValidator),
//             data: abi.encodePacked(uint8(threshold), _getMemberCmts(memberNum))
//         });

//         smartAcct.installModule({
//             moduleTypeId: MODULE_TYPE_EXECUTOR,
//             module: address(semaphoreExecutor),
//             data: hex""
//         });

//         _;
//     }

//     modifier deploySimpleContract() {
//         simpleContract = new SimpleContract(0);
//         _;
//     }

//     /**
//      * Internal helper functions
//      */
//     function _getMemberCmts(uint8 num) internal returns (uint256[] memory cmts) {
//         cmts = new uint256[](num);
//         for (uint8 i = 0; i < num; ++i) {
//             cmts[i] = $users[i].identity.commitment();
//         }
//         cmts.insertionSort();
//     }

//     function _getSemaphoreValidatorUserOpData(
//         Identity id,
//         bytes memory callData,
//         uint256 value
//     )
//         internal
//         returns (UserOpData memory userOpData)
//     {
//         userOpData = smartAcct.getExecOps({
//             target: address(semaphoreValidator),
//             value: value,
//             callData: callData,
//             txValidator: address(semaphoreValidator)
//         });

//         // We need to increase the accountGasLimits, default 2e6 is not enough to verify
//         // signature, for all those elliptic curve computation.
//         // Encoding two fields here, validation and execution gas
//         userOpData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e7),
// uint128(2e7)));
//         userOpData.userOpHash = smartAcct.aux.entrypoint.getUserOpHash(userOpData.userOp);
//         userOpData.userOp.signature = id.signHash(userOpData.userOpHash);
//     }

//     function _getSemaphoreValExeUserOpData(
//         Identity id,
//         bytes memory callData,
//         uint256 value
//     )
//         internal
//         returns (UserOpData memory userOpData)
//     {
//         userOpData = smartAcct.getExecOps({
//             target: address(semaphoreExecutor),
//             value: value,
//             callData: callData,
//             txValidator: address(semaphoreValidator)
//         });

//         // We need to increase the accountGasLimits, default 2e6 is not enough to verify
//         // signature, for all those elliptic curve computation.
//         // Encoding two fields here, validation and execution gas
//         userOpData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e7),
// uint128(2e7)));
//         userOpData.userOpHash = smartAcct.aux.entrypoint.getUserOpHash(userOpData.userOp);
//         userOpData.userOp.signature = id.signHash(userOpData.userOpHash);
//     }

//     function _setupInitiateTxMultiMembers(
//         bytes memory txCallData,
//         uint256 value,
//         bool bExecute
//     )
//         internal
//         setupSmartAcctWithMembersThreshold(MEMBER_NUM, 2)
//         deploySimpleContract
//         returns (UserOpData memory userOpData, bytes32 txHash)
//     {
//         User storage member = $users[0];
//         // Composing txHash
//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);
//         txHash = keccak256(abi.encodePacked(seq, address(simpleContract), value, txCallData));

//         // Composing Semaphore proof
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof =
//             member.identity.generateSempahoreProof(groupId, _getMemberCmts(MEMBER_NUM), txHash);

//         // Composing the UserOpData
//         userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(
//                 SemaphoreMSAValidator.initiateTx,
//                 (address(simpleContract), txCallData, smProof, bExecute)
//             ),
//             value
//         );
//     }

//     function _setupValExeInitiateTxMultiMembers(
//         bytes memory txCallData,
//         uint256 value,
//         bool bExecute
//     )
//         internal
//         setupSmartAcctValExeWithMembersThreshold(MEMBER_NUM, 2)
//         deploySimpleContract
//         returns (UserOpData memory userOpData, bytes32 txHash)
//     {
//         User storage member = $users[0];
//         // Composing txHash
//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);
//         txHash = keccak256(abi.encodePacked(seq, address(simpleContract), value, txCallData));

//         // Composing Semaphore proof
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof =
//             member.identity.generateSempahoreProof(groupId, _getMemberCmts(MEMBER_NUM), txHash);

//         // Composing the UserOpData
//         userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(
//                 SemaphoreMSAValidator.initiateTx,
//                 (address(simpleContract), txCallData, smProof, bExecute)
//             ),
//             value
//         );
//     }

//     /**
//      * Tests
//      */
//     function test_onInstallWithOneMember() public setupSmartAcctWithMembersThreshold(1, 1) {
//         assertEq(semaphoreValidator.thresholds(smartAcct.account), 1);
//         assertEq(semaphoreValidator.memberCount(smartAcct.account), 1);
//         assertEq(semaphoreValidator.isInitialized(smartAcct.account), true);

//         (bool bExist, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         assertEq(bExist, true);
//         assertEq(groupId, 0);
//     }

//     function test_onInstallWithInvalidData() public {
//         smartAcct = makeAccountInstance("SemaphoreMSAValidator");
//         vm.deal(smartAcct.account, 1 ether);

//         // Test: InvalidInstallData
//         smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidInstallData.selector);
//         smartAcct.installModule({
//             moduleTypeId: MODULE_TYPE_VALIDATOR,
//             module: address(semaphoreValidator),
//             data: abi.encodePacked(bytes16(hex"deadbeef"))
//         });
//     }

//     function test_duplicateInstall() public setupSmartAcctWithMembersThreshold(1, 1) {
//         // The modifier has already installed the validator in smartAcct
//         uint256[] memory cmts = new uint256[](1);
//         cmts[0] = $users[0].identity.commitment();

//         // Test: should revert due to duplicate install
//         smartAcct.expect4337Revert();
//         smartAcct.installModule({
//             moduleTypeId: MODULE_TYPE_VALIDATOR,
//             module: address(semaphoreValidator),
//             data: abi.encodePacked(uint8(1), cmts)
//         });
//     }

//     function test_onUninstall() public setupSmartAcctWithMembersThreshold(1, 1) {
//         smartAcct.uninstallModule({
//             moduleTypeId: MODULE_TYPE_VALIDATOR,
//             module: address(semaphoreValidator),
//             data: ""
//         });

//         assertEq(semaphoreValidator.thresholds(smartAcct.account), 0);
//         assertEq(semaphoreValidator.memberCount(smartAcct.account), 0);
//         assertEq(semaphoreValidator.isInitialized(smartAcct.account), false);

//         (bool bExist,) = semaphoreValidator.getGroupId(smartAcct.account);
//         assertEq(bExist, false);
//     }

//     function test_initiateTransferInvalidSignature()
//         public
//         setupSmartAcctWithMembersThreshold(1, 1)
//     {
//         User storage member = $users[0];
//         User storage recipient = $users[1];
//         UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(
//                 SemaphoreMSAValidator.initiateTx,
//                 (recipient.addr, "", getEmptySemaphoreProof(), false)
//             ),
//             1 ether
//         );
//         userOpData.userOp.signature[0] = hex"ff";
//         userOpData.userOp.signature[1] = hex"ff";

//         smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSignature.selector);
//         userOpData.execUserOps();
//     }

//     function test_initiateTransferInvalidSemaphoreProof()
//         public
//         setupSmartAcctWithMembersThreshold(1, 1)
//     {
//         User storage member = $users[0];
//         User storage recipient = $users[1];
//         UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(
//                 SemaphoreMSAValidator.initiateTx,
//                 (recipient.addr, "", getEmptySemaphoreProof(), false)
//             ),
//             1 ether
//         );

//         smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSemaphoreProof.selector);
//         userOpData.execUserOps();
//     }

//     function _setupInitiateTransferSingleMember() internal returns (bytes32, address, uint256) {
//         return _setupInitiateTransferSingleMember(false, false);
//     }

//     function _setupInitiateTransferSingleMember(
//         bool bExecute,
//         bool bExpectExecute
//     )
//         internal
//         setupSmartAcctWithMembersThreshold(1, 1)
//         returns (bytes32 txHash, address targetAddr, uint256 value)
//     {
//         User storage member = $users[0];
//         targetAddr = $users[1].addr;
//         value = 1 ether;

//         // Composing txHash
//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);
//         txHash = keccak256(abi.encodePacked(seq, targetAddr, value, ""));

//         // Composing Semaphore proof
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof =
//             member.identity.generateSempahoreProof(groupId, _getMemberCmts(1), txHash);

//         // Get Semaphore validator UserOpData (and signature)
//         UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(SemaphoreMSAValidator.initiateTx, (targetAddr, "", smProof,
// bExecute)),
//             value
//         );

//         // Expecting `InitiatedTx` event to be emitted
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.InitiatedTx(smartAcct.account, seq, txHash);

//         // Expecting `ExecutedTx` event based on parameter
//         if (bExpectExecute) {
//             vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//             emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);
//         }
//         userOpData.execUserOps();
//     }

//     function test_initiateTransferSingleMember() public {
//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);

//         (bytes32 txHash, address targetAddr, uint256 value) =
// _setupInitiateTransferSingleMember();

//         // Test the states are changed accordingly
//         assertEq(semaphoreValidator.acctSeqNum(smartAcct.account), seq + 1);

//         (address eccTargetAddr, bytes memory eccCallData, uint256 eccValue, uint8 eccCount) =
//             semaphoreValidator.acctTxCount(smartAcct.account, txHash);

//         assertEq(eccTargetAddr, targetAddr);
//         assertEq(eccValue, value);
//         assertEq(eccCallData, "");
//         assertEq(eccCount, 1);
//     }

//     function test_initiateTransferSingleMemberExecuteInvalidTxHash() public {
//         (bytes32 forgedHash,,) = _setupInitiateTransferSingleMember();
//         // Changed the last 2 bytes to 0xffff
//         forgedHash |= bytes32(uint256(0xffff));

//         User storage member = $users[0];

//         UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity, abi.encodeCall(SemaphoreMSAValidator.executeTx, (forgedHash)), 0
//         );

//         smartAcct.expect4337Revert(
//             abi.encodeWithSelector(
//                 SemaphoreMSAValidator.TxHashNotFound.selector, smartAcct.account, forgedHash
//             )
//         );
//         userOpData.execUserOps();
//     }

//     function test_initiateTransferSingleMemberExecute() public {
//         User storage member = $users[0];
//         (bytes32 txHash, address targetAddr, uint256 value) =
// _setupInitiateTransferSingleMember();
//         uint256 beforeBalance = targetAddr.balance;

//         UserOpData memory userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity, abi.encodeCall(SemaphoreMSAValidator.executeTx, (txHash)), 0
//         );

//         // Test event emission
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);
//         userOpData.execUserOps();

//         uint256 afterBalance = targetAddr.balance;
//         assertEq(afterBalance - beforeBalance, value);
//     }

//     function test_initiateTransferSingleMemberExecuteCombined() public {
//         address recipientAddr = $users[1].addr;
//         uint256 beforeBalance = recipientAddr.balance;
//         (, address targetAddr, uint256 value) = _setupInitiateTransferSingleMember(true, true);

//         // Test: user balance has updated
//         assert(recipientAddr == targetAddr);
//         uint256 afterBalance = targetAddr.balance;
//         assertEq(afterBalance - beforeBalance, value);
//     }

//     function test_initiateTxSingleMemberInvalidTargetAddress()
//         public
//         setupSmartAcctWithMembersThreshold(1, 1)
//         deploySimpleContract
//     {
//         User storage member = $users[0];
//         uint256 testVal = 7;

//         // Test: non-validator target is disallowed
//         UserOpData memory userOpData = smartAcct.getExecOps({
//             target: address(simpleContract),
//             value: 0,
//             callData: abi.encodeCall(SimpleContract.setVal, (testVal)),
//             txValidator: address(semaphoreValidator)
//         });
//         userOpData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e7),
// uint128(2e7)));
//         userOpData.userOpHash = smartAcct.aux.entrypoint.getUserOpHash(userOpData.userOp);
//         userOpData.userOp.signature = member.identity.signHash(userOpData.userOpHash);

//         smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidTargetAddress.selector);
//         userOpData.execUserOps();
//     }

//     function _setupInitiateTxSingleMember(
//         bytes memory txCallData,
//         bool bExecute
//     )
//         internal
//         setupSmartAcctWithMembersThreshold(1, 1)
//         deploySimpleContract
//         returns (UserOpData memory userOpData, bytes32 txHash)
//     {
//         User storage member = $users[0];
//         // Composing txHash
//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);
//         address targetAddr = address(simpleContract);
//         txHash = keccak256(abi.encodePacked(seq, targetAddr, uint256(0), txCallData));

//         // Composing Semaphore proof
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof =
//             member.identity.generateSempahoreProof(groupId, _getMemberCmts(1), txHash);

//         // Get Semaphore validator UserOpData (and signature)
//         userOpData = _getSemaphoreValidatorUserOpData(
//             member.identity,
//             abi.encodeCall(
//                 SemaphoreMSAValidator.initiateTx, (targetAddr, txCallData, smProof, bExecute)
//             ),
//             0
//         );
//     }

//     function test_initiateTxSingleMemberSignExecuteTx() public {
//         uint256 testVal = 7;
//         bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));

//         (UserOpData memory userOpData, bytes32 txHash) =
//             _setupInitiateTxSingleMember(txCallData, true);

//         uint256 seq = semaphoreValidator.getAcctSeqNum(smartAcct.account);

//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.InitiatedTx(smartAcct.account, seq, txHash);
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);
//         userOpData.execUserOps();

//         // Test: the deployed contract value is updated
//         assertEq(simpleContract.val(), testVal);
//     }

//     function test_initiateTxSingleMemberInvalidExecuteTx() public {
//         uint256 testVal = 7;
//         bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
//         // Invalidate the txCallData
//         txCallData[0] = hex"ff";
//         txCallData[1] = hex"ff";

//         (UserOpData memory userOpData,) = _setupInitiateTxSingleMember(txCallData, true);

//         // Expect ExecuteTxFailure error
//         smartAcct.expect4337Revert(SemaphoreMSAValidator.ExecuteTxFailure.selector);
//         userOpData.execUserOps();
//     }

//     function test_initiateTxMultiMembersCannotDoubleSign() public {
//         uint256 testVal = 7;
//         bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
//         (UserOpData memory userOpData, bytes32 txHash) =
//             _setupInitiateTxMultiMembers(txCallData, 0, true);
//         userOpData.execUserOps();

//         User storage doubleSigner = $users[0];
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof = doubleSigner.identity.generateSempahoreProof(
//             groupId, _getMemberCmts(MEMBER_NUM), txHash
//         );

//         // Composing the UserOpData
//         UserOpData memory userOpData2 = _getSemaphoreValidatorUserOpData(
//             doubleSigner.identity,
//             abi.encodeCall(SemaphoreMSAValidator.signTx, (txHash, smProof, true)),
//             0
//         );

//         smartAcct.expect4337Revert(SemaphoreMSAValidator.InvalidSemaphoreProof.selector);
//         userOpData2.execUserOps();
//     }

//     function test_initiateTxMultiMembersSignTx() public {
//         uint256 testVal = 7;
//         bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (testVal));
//         (UserOpData memory userOpData, bytes32 txHash) =
//             _setupInitiateTxMultiMembers(txCallData, 0, true);
//         userOpData.execUserOps();

//         User storage anotherSigner = $users[1];
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof = anotherSigner.identity.generateSempahoreProof(
//             groupId, _getMemberCmts(MEMBER_NUM), txHash
//         );

//         // Composing the UserOpData
//         UserOpData memory userOpData2 = _getSemaphoreValidatorUserOpData(
//             anotherSigner.identity,
//             abi.encodeCall(SemaphoreMSAValidator.signTx, (txHash, smProof, false)),
//             0
//         );

//         // Expect SignedTx event
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.SignedTx(smartAcct.account, txHash);
//         userOpData2.execUserOps();

//         // Check the state
//         (,,, uint8 eccCount) = semaphoreValidator.acctTxCount(smartAcct.account, txHash);
//         assertEq(eccCount, 2);
//     }

//     function test_initiateTxMultiMembersSignExecuteTx() public {
//         uint256 newVal = 7;
//         uint256 msgVal = 100;

//         bytes memory txCallData = abi.encodeCall(SimpleContract.setVal, (newVal));
//         (UserOpData memory userOpData, bytes32 txHash) =
//             _setupValExeInitiateTxMultiMembers(txCallData, msgVal, true);
//         userOpData.execUserOps();

//         console.log("completed sign - 1");
//         console.logBytes32(txHash);

//         console.log("smartAcct addr: %s, value: %s", smartAcct.account,
// smartAcct.account.balance);

//         User storage recipient = $users[2];

//         User storage anotherSigner = $users[1];
//         (, uint256 groupId) = semaphoreValidator.getGroupId(smartAcct.account);
//         ISemaphore.SemaphoreProof memory smProof = anotherSigner.identity.generateSempahoreProof(
//             groupId, _getMemberCmts(MEMBER_NUM), txHash
//         );

//         // Composing the UserOpData
//         UserOpData memory userOpData2 = _getSemaphoreValExeUserOpData(
//             anotherSigner.identity,
//             // abi.encodeCall(SemaphoreMSAExecutor.executeTx, (txHash, smProof, true)),
//             abi.encodeCall(SemaphoreMSAExecutor.executeTx, (recipient.addr, msgVal, hex"")),
//             0
//         );

//         // Expect SignedTx, ValueSet, and ExecuteTx events
//         // vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         // emit SemaphoreMSAValidator.SignedTx(smartAcct.account, txHash);

//         // vm.expectEmit(true, true, true, true, address(simpleContract));
//         // emit SimpleContract.ValueSet(smartAcct.account, msgVal, newVal);

//         // vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         // emit SemaphoreMSAValidator.ExecutedTx(smartAcct.account, txHash);

//         console.log("before execUserOps - 2");

//         userOpData2.execUserOps();

//         // Check the state
//         // assertEq(simpleContract.val(), newVal);

//         console.log("recipient value: %s", recipient.addr.balance);
//         console.log("smartAcct value: %s", smartAcct.account.balance);
//     }

//     function test_addMembers() public setupSmartAcctWithMembersThreshold(1, 1) {
//         Identity newIdentity = $users[1].identity;
//         uint256 newCommitment = newIdentity.commitment();

//         // Compose the userOp
//         PackedUserOperation memory userOp = getEmptyUserOperation();
//         userOp.sender = smartAcct.account;
//         userOp.callData = getTestUserOpCallData(
//             0,
//             address(semaphoreValidator),
//             abi.encodeWithSelector(SemaphoreMSAValidator.initiateTx.selector)
//         );
//         bytes32 userOpHash = bytes32(keccak256("userOpHash"));
//         userOp.signature = newIdentity.signHash(userOpHash);

//         // expecting the vm to revert
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 SemaphoreMSAValidator.MemberNotExists.selector, smartAcct.account, newCommitment
//             )
//         );
//         semaphoreValidator.validateUserOp(userOp, userOpHash);

//         // Now we add the new member
//         uint256[] memory newMembers = new uint256[](1);
//         newMembers[0] = newCommitment;

//         // Test: addMembers() is successfully executed
//         vm.startPrank(smartAcct.account);
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.AddedMembers(smartAcct.account, uint256(1));
//         semaphoreValidator.addMembers(newMembers);
//         vm.stopPrank();

//         assertEq(semaphoreValidator.memberCount(smartAcct.account), 2);

//         // Test: the userOp should pass
//         uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
//             semaphoreValidator.validateUserOp(userOp, userOpHash)
//         );
//         assertEq(validationData, VALIDATION_SUCCESS);
//     }

//     function test_removeMember() public setupSmartAcctWithMembersThreshold(MEMBER_NUM, 1) {
//         uint256[] memory cmts = _getMemberCmts(MEMBER_NUM);
//         User storage rmUser = $users[0];
//         uint256 rmCmt = rmUser.identity.commitment();

//         (uint256[] memory merkleProof,) = getGroupRmMerkleProof(cmts, rmCmt);

//         // Test: remove member
//         vm.startPrank(smartAcct.account);
//         vm.expectEmit(true, true, true, true, address(semaphoreValidator));
//         emit SemaphoreMSAValidator.RemovedMember(smartAcct.account, rmCmt);
//         semaphoreValidator.removeMember(rmCmt, merkleProof);
//         vm.stopPrank();

//         assertEq(semaphoreValidator.memberCount(smartAcct.account), MEMBER_NUM - 1);

//         // Compose a UserOp
//         PackedUserOperation memory userOp = getEmptyUserOperation();
//         userOp.sender = smartAcct.account;
//         userOp.callData = getTestUserOpCallData(
//             0,
//             address(semaphoreValidator),
//             abi.encodeWithSelector(SemaphoreMSAValidator.initiateTx.selector)
//         );
//         bytes32 userOpHash = bytes32(keccak256("userOpHash"));
//         userOp.signature = rmUser.identity.signHash(userOpHash);

//         // Test: the userOp should fail and revert
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 SemaphoreMSAValidator.MemberNotExists.selector, smartAcct.account, rmCmt
//             )
//         );
//         semaphoreValidator.validateUserOp(userOp, userOpHash);
//     }
// }
