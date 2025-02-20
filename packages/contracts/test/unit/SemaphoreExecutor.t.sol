// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// Rhinestone Modulekit
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR,
    VALIDATION_SUCCESS
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { ISemaphore } from "src/interfaces/Semaphore.sol";
import { SemaphoreValidator, ERC7579ValidatorBase } from "src/SemaphoreValidator.sol";
import { ExtCallCount, SemaphoreExecutor, SENTINEL } from "src/SemaphoreExecutor.sol";

import { LibBytes } from "solady/Milady.sol";
import {
    getEmptyUserOperation,
    getTestUserOpCallData,
    getGroupRmMerkleProof,
    Identity,
    IdentityLib
} from "test/utils/TestUtils.sol";

import { SharedTestSetup, User } from "test/utils/SharedTestSetup.sol";
import { NUM_MEMBERS } from "test/utils/Constants.sol";

contract SemaphoreExecutorTest is SharedTestSetup {
    using ModuleKitHelpers for *;
    using IdentityLib for Identity;

    /**
     * Tests
     */
    function test_onInstall_RevertWithInvalidData() public {
        // Test: InvalidInstallData
        smartAcct.expect4337Revert(SemaphoreExecutor.InvalidInstallData.selector);
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(bytes16(hex"deadbeef"))
        });
    }

    function test_onInstall_Pass() public {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(1), _getMemberCmts(1))
        });

        User memory member = $users[0];

        assertEq(semaphoreExecutor.thresholds(smartAcct.account), 1);
        assertEq(semaphoreExecutor.accountMemberCount(smartAcct.account), 1);
        assertEq(semaphoreExecutor.isInitialized(smartAcct.account), true);

        (bool bExist, uint256 groupId) = semaphoreExecutor.getGroupId(smartAcct.account);
        assertEq(bExist, true);

        assertEq(groupId, 0);
        assertEq(
            semaphoreExecutor.accountHasMember(smartAcct.account, member.identity.commitment()),
            true
        );
    }

    function test_onInstall_KeepMemberAscOrder() public {
        uint256 gId = 0;

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(
                uint8(2),
                [
                    11_607_007_807_378_753_003_975_429_250_673_965_311_744_748_125_068_817_954_862_939_553_263_009_294_467,
                    2_106_140_715_974_798_855_160_070_883_852_634_960_091_865_760_146_834_573_070_109_796_353_803_304_118,
                    4_950_121_590_542_886_510_054_876_111_383_682_513_486_057_475_224_966_179_062_467_605_780_876_843_365
                ]
            )
        });

        assertEq(semaphore.getMerkleTreeSize(gId), 3);
        assertEq(
            semaphore.indexOf(
                0,
                2_106_140_715_974_798_855_160_070_883_852_634_960_091_865_760_146_834_573_070_109_796_353_803_304_118
            ),
            0
        );
        assertEq(
            semaphore.indexOf(
                0,
                4_950_121_590_542_886_510_054_876_111_383_682_513_486_057_475_224_966_179_062_467_605_780_876_843_365
            ),
            1
        );
        assertEq(
            semaphore.indexOf(
                0,
                11_607_007_807_378_753_003_975_429_250_673_965_311_744_748_125_068_817_954_862_939_553_263_009_294_467
            ),
            2
        );
    }

    function test_onUninstall_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        // Uninsstall the validator first
        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        smartAcct.uninstallModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: ""
        });

        assertEq(semaphoreExecutor.thresholds(smartAcct.account), 0);
        (bool bExist,) = semaphoreExecutor.getGroupId(smartAcct.account);
        assertEq(bExist, false);
        assertEq(semaphoreExecutor.accountMemberCount(smartAcct.account), 0);
        assertEq(semaphoreExecutor.isInitialized(smartAcct.account), false);
    }

    function test_addMembers_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        uint256[] memory newMembers = new uint256[](1);
        Identity newIdentity = $users[1].identity;
        newMembers[0] = newIdentity.commitment();

        // Compose a userOp
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor),
            0,
            abi.encodeWithSelector(SemaphoreExecutor.initiateTx.selector)
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));
        userOp.signature = newIdentity.signHash(userOpHash);

        // Test: The userOp should fail, as $users[1].identity is not a member yet
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreValidator.MemberNotExists.selector,
                smartAcct.account,
                LibBytes.slice(userOp.signature, 0, 64)
            )
        );
        semaphoreValidator.validateUserOp(userOp, userOpHash);

        // Test: addMembers() is successfully executed
        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true, address(semaphoreExecutor));
        emit SemaphoreExecutor.AddedMembers(smartAcct.account, uint8(1));
        semaphoreExecutor.addMembers(newMembers);
        vm.stopPrank();

        assertEq(semaphoreExecutor.accountMemberCount(smartAcct.account), 2);
        assertEq(semaphoreExecutor.accountHasMember(smartAcct.account, newMembers[0]), true);

        // Test: the userOp should pass now
        uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );
        assertEq(validationData, VALIDATION_SUCCESS);
    }

    function test_removeMember_Pass() public setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1) {
        uint256[] memory cmts = _getMemberCmts(NUM_MEMBERS);
        Identity rmIdentity = $users[0].identity;
        uint256 rmCmt = rmIdentity.commitment();

        // We have to first find the prev Cmt (outsdie of the code). Also note that
        // sentinellist is a reversed linked list
        uint256 prevCmt = uint256(uint160(SENTINEL));

        (uint256[] memory merkleProof,) = getGroupRmMerkleProof(cmts, rmCmt);

        // Test: remove member
        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true, address(semaphoreExecutor));
        emit SemaphoreExecutor.RemovedMember(smartAcct.account, rmCmt);

        semaphoreExecutor.removeMember(prevCmt, rmCmt, merkleProof);

        vm.stopPrank();

        assertEq(semaphoreExecutor.accountMemberCount(smartAcct.account), NUM_MEMBERS - 1);
        assertEq(semaphoreExecutor.accountHasMember(smartAcct.account, rmCmt), false);

        // Compose a UserOp
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData = getTestUserOpCallData(
            address(semaphoreExecutor),
            0,
            abi.encodeWithSelector(SemaphoreExecutor.initiateTx.selector)
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));
        userOp.signature = rmIdentity.signHash(userOpHash);

        // Test: the userOp should fail and revert
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreValidator.MemberNotExists.selector,
                smartAcct.account,
                LibBytes.slice(userOp.signature, 0, 64)
            )
        );
        semaphoreValidator.validateUserOp(userOp, userOpHash);
    }

    function test_setThreshold_InvalidThreshold()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, NUM_MEMBERS)
    {
        // Test: setThreshold() cannot set to be more than number of members
        vm.startPrank(smartAcct.account);
        vm.expectRevert(
            abi.encodeWithSelector(SemaphoreExecutor.InvalidThreshold.selector, smartAcct.account)
        );
        semaphoreExecutor.setThreshold(NUM_MEMBERS + 1);
    }

    function test_setThreshold_Pass()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, NUM_MEMBERS)
    {
        uint8 newThreshold = 1;

        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ThresholdSet(smartAcct.account, newThreshold);
        semaphoreExecutor.setThreshold(newThreshold);
        vm.stopPrank();

        assertEq(semaphoreExecutor.thresholds(smartAcct.account), newThreshold);
    }

    function test_initiateTx_NullTargetShouldRevert()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1)
    {
        Identity self = $users[0].identity;
        address target = address(0);
        uint256 value = 100;
        bytes memory txCallData = "";
        uint256 gId = 0;

        // Compose txHash and semaphore proof
        bytes32 txHash = keccak256(abi.encodePacked(uint256(0), target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof =
            self.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        // Test: should fail as target is null
        vm.startPrank(smartAcct.account);
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreExecutor.InitiateTxWithNullAddress.selector, smartAcct.account
            )
        );
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof, true);
    }

    function test_initiateTx_InvalidSemaphoreProof()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1)
    {
        Identity self = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 100;
        bytes memory txCallData = "";
        uint256 gId = 0;

        // Compose txHash and semaphore proof. Then mess with the proof
        bytes32 txHash = keccak256(abi.encodePacked(uint256(0), target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof =
            self.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);
        smProof.points[0] = 1;

        // Test: should fail as proof has been forged
        vm.startPrank(smartAcct.account);
        vm.expectPartialRevert(SemaphoreExecutor.InvalidSemaphoreProof.selector);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof, true);
    }

    function test_initiateTx_Pass() public setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1) {
        Identity self = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 100;
        bytes memory txCallData = hex"deadbeef";
        uint256 gId = 0;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(uint256(0), target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof =
            self.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        vm.startPrank(smartAcct.account);
        // Test: InitiatedTx event is emitted
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.InitiatedTx(smartAcct.account, uint256(0), txHash);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof, false);
        vm.stopPrank();

        ExtCallCount memory ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);

        // Test: the storage state is updated
        assertEq(ecc.targetAddr, target, "test_initiateTx_Pass_targetAddr");
        assertEq(ecc.callData, txCallData, "test_initiateTx_Pass_callData");
        assertEq(ecc.value, value, "test_initiateTx_Pass_value");
        assertEq(ecc.count, 1, "test_initiateTx_Pass_count");
    }

    function test_initiateTx_AndExecutePass()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1)
    {
        Identity self = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 1 ether;
        bytes memory txCallData = "";
        uint256 gId = 0;

        uint256 receiverBefore = target.balance;
        uint256 senderBefore = smartAcct.account.balance;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(uint256(0), target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof =
            self.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        // Test: expect the tx is signed and immediately call executeTx()
        vm.startPrank(smartAcct.account);
        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ExecutedTx(smartAcct.account, txHash);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof, true);
        vm.stopPrank();

        // Check: the internal state ecc should have been deleted
        ExtCallCount memory ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);
        assertEq(ecc.targetAddr, address(0));

        // Check: balance of sender and receiver
        uint256 receiverAfter = target.balance;
        uint256 senderAfter = smartAcct.account.balance;
        assertEq(receiverAfter - receiverBefore, value, "test_initiateTx_AndExecutePass_receiver");
        assertApproxEqRel(
            senderBefore - senderAfter, value, 0.001e18, "test_initiateTx_AndExecutePass_sender"
        );
    }

    function test_signTx_TxNotFound() public setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 1) {
        Identity self = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 100;
        bytes memory txCallData = "";
        uint256 gId = 0;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(uint256(0), target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof =
            self.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        // Test: expect the tx is reverted
        vm.startPrank(smartAcct.account);
        vm.expectRevert(
            abi.encodeWithSelector(SemaphoreExecutor.TxNotFound.selector, smartAcct.account, txHash)
        );
        semaphoreExecutor.signTx(txHash, smProof, true);
        vm.stopPrank();
    }

    function test_signTx_Pass() public setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 2) {
        Identity user1 = $users[0].identity;
        Identity user2 = $users[1].identity;
        address target = $users[1].addr;
        uint256 value = 100;
        bytes memory txCallData = "";
        uint256 gId = 0;
        uint256 seq = 0;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(seq, target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof1 =
            user1.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);
        ISemaphore.SemaphoreProof memory smProof2 =
            user2.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        vm.startPrank(smartAcct.account);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof1, true);

        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.SignedTx(smartAcct.account, txHash);
        semaphoreExecutor.signTx(txHash, smProof2, false);
        vm.stopPrank();

        // Check: the internal state ecc should have been deleted
        ExtCallCount memory ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);
        assertEq(ecc.count, 2, "test_signTx_Pass_count");
    }

    function test_executeTx_ThresholdNotReach()
        public
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 2)
    {
        Identity user1 = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 100;
        bytes memory txCallData = "";
        uint256 gId = 0;
        uint256 seq = 0;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(seq, target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof1 =
            user1.getSempahoreProof(gId, _getMemberCmts(NUM_MEMBERS), txHash);

        vm.startPrank(smartAcct.account);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof1, true);

        // Test: expect ThresholdNotReach error
        vm.expectRevert(
            abi.encodeWithSelector(
                SemaphoreExecutor.ThresholdNotReach.selector, smartAcct.account, 2, 1
            )
        );
        semaphoreExecutor.executeTx(txHash);
    }

    function test_executeTx_Pass() public setupSmartAcctWithMembersThreshold(1, 1) {
        Identity user1 = $users[0].identity;
        address target = $users[1].addr;
        uint256 value = 1 ether;
        bytes memory txCallData = "";
        uint256 gId = 0;
        uint256 seq = 0;

        uint256 receiverBefore = target.balance;

        // Compose txHash and semaphore proof.
        bytes32 txHash = keccak256(abi.encodePacked(seq, target, value, txCallData));
        ISemaphore.SemaphoreProof memory smProof1 =
            user1.getSempahoreProof(gId, _getMemberCmts(1), txHash);

        vm.startPrank(smartAcct.account);
        semaphoreExecutor.initiateTx(target, value, txCallData, smProof1, false);

        vm.expectEmit(true, true, true, true);
        emit SemaphoreExecutor.ExecutedTx(smartAcct.account, txHash);
        semaphoreExecutor.executeTx(txHash);

        vm.stopPrank();

        // Test: state has changed
        uint256 receiverAfter = target.balance;
        assertEq(receiverAfter - receiverBefore, value, "test_executeTx_Pass_value");

        // ecc should have been deleted
        ExtCallCount memory ecc = semaphoreExecutor.getAcctTx(smartAcct.account, txHash);
        assertEq(ecc.targetAddr, address(0), "test_executeTx_Pass_targetAddr");
    }
}
