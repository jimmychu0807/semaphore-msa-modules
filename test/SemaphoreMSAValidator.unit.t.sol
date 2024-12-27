// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";

import {
    Semaphore,
    ISemaphore,
    ISemaphoreGroups,
    ISemaphoreVerifier,
    SemaphoreVerifier
} from "../src/utils/Semaphore.sol";

import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "../src/SemaphoreMSAValidator.sol";

import { IERC7579Module, IERC7579Validator } from "modulekit/Modules.sol";
import {
    VALIDATION_SUCCESS,
    VALIDATION_FAILED,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import {
    getEmptyUserOperation,
    getEmptySemaphoreProof,
    Identity,
    IdentityLib
} from "./utils/TestUtils.sol";
import { LibSort } from "solady/utils/LibSort.sol";

struct User {
    uint256 sk;
    address addr;
    uint256 cmt; // user commitment
}

contract SemaphoreValidatorUnitTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreMSAValidator internal semaphoreValidator;
    User[] $users;
    uint256[] $memberCmts = [
        uint256(18699903263915756199535533399390350858126023699350081471896734858638858200219),
        uint256(4446973358529698253939037684201229393105675634248270727935122282482202195132),
        uint256(16658210975476022044027345155568543847928305944324616901189666478659011192021)
    ];

    function setUp() public virtual {
        // init() function comes from contract AuxiliaryFactory:
        //   https://github.com/rhinestonewtf/modulekit/blob/main/src/test/Auxiliary.sol
        super.init();

        // Deploy Semaphore
        SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
        vm.label(address(semaphoreVerifier), "SemaphoreVerifier");
        Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
        vm.label(address(semaphore), "Semaphore");

        // Create the validator
        semaphoreValidator = new SemaphoreMSAValidator(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreMSAValidator");

        // Create two users
        (address addr, uint256 sk) = makeAddrAndKey("user1");
        vm.deal(addr, 10 ether);
        $users.push(User({ sk: sk, addr: addr, cmt: 1 }));

        (addr, sk) = makeAddrAndKey("user2");
        vm.deal(addr, 10 ether);
        $users.push(User({ sk: sk, addr: addr, cmt: 2 }));
    }

    modifier setupSmartAcctOneUser() {
        // Create the smart account and install the validator with one admin
        smartAcct = makeAccountInstance("SemaphoreMSAValidator");
        vm.deal(smartAcct.account, 10 ether);
        uint256[] memory cmts = new uint256[](1);
        cmts[0] = $users[0].cmt;
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            // TODO: optimize this to use encodePacked()
            data: abi.encode(uint8(1), cmts)
        });
        _;
    }

    function test_SemaphoreDeployProperly() public {
        ISemaphore semaphore = semaphoreValidator.semaphore();
        ISemaphoreGroups groups = semaphoreValidator.groups();

        User storage admin = $users[0];
        uint256 groupId = semaphore.createGroup(admin.addr);

        // Test 1: non-admin cannot add members. Should revert here
        vm.expectRevert(ISemaphoreGroups.Semaphore__CallerIsNotTheGroupAdmin.selector);
        semaphore.addMember(groupId, uint256(4));

        // Test 2: admin can add member, should have an event emitted
        //   We don't check for the event log data because we don't know the merkle root (4th param)
        //   yet at this point.
        vm.expectEmit(true, true, true, false);
        emit ISemaphoreGroups.MembersAdded(groupId, 0, $memberCmts, 0);

        vm.prank(admin.addr);
        semaphore.addMembers(groupId, $memberCmts);

        // Hard-code a bad proof
        uint256 merkleTreeRoot = groups.getMerkleTreeRoot(groupId);
        uint256 merkleTreeDepth = 2;

        ISemaphore.SemaphoreProof memory badProof = ISemaphore.SemaphoreProof({
            merkleTreeDepth: merkleTreeDepth,
            merkleTreeRoot: merkleTreeRoot,
            nullifier: 0,
            message: 0,
            scope: groupId,
            points: [uint256(0), 0, 0, 0, 0, 0, 0, 0]
        });

        // Test 3: validateProof() should reject invalid proof
        vm.expectRevert(ISemaphore.Semaphore__InvalidProof.selector);
        semaphore.validateProof(groupId, badProof);

        // Hard-code a good proof, generate with js
        uint256[8] memory points = [
            8754155586417785722495470355400612435163491722543495943821566022238250742089,
            9311277326082450661421961776323317578243683731284276799789402550732654540221,
            21085626846082214868906508770789165162256682314918488454768199138554866360967,
            21443185256751033286080864270977332698900979912547135282775393829978819886983,
            6146766603522887336268534704733943707329586494820302567246261601613119898050,
            6045075051598445696915996184912833218616283726504301031952692097009324813608,
            7934176176660057205882670886568952288755193231800611293588747925476169302192,
            13153394304570492498284582612982233846934220238727913230903336758335153705366
        ];

        ISemaphore.SemaphoreProof memory goodProof = ISemaphore.SemaphoreProof({
            merkleTreeDepth: merkleTreeDepth,
            merkleTreeRoot: merkleTreeRoot,
            nullifier: 9258620728367181689082100997241864348984639649085246237074656141003522567612,
            message: 32745724963520459128167607516703083632076522816298193357160756506792738947072,
            scope: groupId,
            points: points
        });

        // Test 4: validateProof() should accept a valid proof and emit ProofValidated event
        vm.expectEmit(true, true, true, true);
        emit ISemaphore.ProofValidated(
            groupId,
            merkleTreeDepth,
            merkleTreeRoot,
            goodProof.nullifier,
            goodProof.message,
            groupId,
            points
        );

        semaphore.validateProof(groupId, goodProof);
    }

    function test_onInstallWithOneUser() public setupSmartAcctOneUser {
        assertEq(semaphoreValidator.groupMapping(smartAcct.account), 0);
        assertEq(semaphoreValidator.thresholds(smartAcct.account), 1);
        assertEq(semaphoreValidator.memberCount(smartAcct.account), 1);
    }

    function test_ValidateUserOpWithProperParams_OneUser() public setupSmartAcctOneUser {
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = smartAcct.account;
        userOp.callData =
            abi.encodeCall(SemaphoreMSAValidator.initiateTx, ("", getEmptySemaphoreProof(), false));

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        Identity id = IdentityLib.genIdentity(1);
        userOp.signature = id.signHash(userOpHash);
        uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
            semaphoreValidator.validateUserOp(userOp, userOpHash)
        );

        assertEq(validationData, VALIDATION_SUCCESS);
    }
}
