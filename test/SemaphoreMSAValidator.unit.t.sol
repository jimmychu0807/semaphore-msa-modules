// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
// import { console } from "forge-std/console.sol";

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
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { getEmptyUserOperation } from "./utils/ModuleKit.sol";
import { signHash } from "./utils/Signature.sol";

import { LibSort } from "solady/utils/LibSort.sol";

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

contract SemaphoreValidatorUnitTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;

    AccountInstance internal smartAcct;
    SemaphoreMSAValidator internal semaphoreValidator;

    uint256 cmt1 = 1;
    uint256 cmt2 = 2;

    uint256 $threshold = 2;
    address[] $users;
    uint256[] $userSks;

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
        (address _user1, uint256 _user1Sk) = makeAddrAndKey("user1");
        (address _user2, uint256 _user2Sk) = makeAddrAndKey("user2");

        // deal some money to the test users
        vm.deal(_user1, 10 ether);
        vm.deal(_user2, 10 ether);

        // Store user info in our storage
        $users.push(_user1);
        $users.push(_user2);
        $userSks.push(_user1Sk);
        $userSks.push(_user2Sk);
    }

    function test_SemaphoreDeployProperly() public {
        ISemaphore semaphore = semaphoreValidator.semaphore();
        ISemaphoreGroups groups = semaphoreValidator.groups();

        address admin = $users[0];
        uint256 groupId = semaphore.createGroup(admin);

        // Test Add members
        uint256[] memory members = new uint256[](3);
        members[0] = uint256(
            18_699_903_263_915_756_199_535_533_399_390_350_858_126_023_699_350_081_471_896_734_858_638_858_200_219
        );
        members[1] = uint256(
            4_446_973_358_529_698_253_939_037_684_201_229_393_105_675_634_248_270_727_935_122_282_482_202_195_132
        );
        members[2] = uint256(
            16_658_210_975_476_022_044_027_345_155_568_543_847_928_305_944_324_616_901_189_666_478_659_011_192_021
        );

        // Test 1: non-admin cannot add members. Should revert here
        vm.expectRevert(ISemaphoreGroups.Semaphore__CallerIsNotTheGroupAdmin.selector);
        semaphore.addMember(groupId, uint256(4));

        // Test 2: admin can add member, should have an event emitted
        //   We don't check for the event log data because we don't know the merkle root (4th param)
        //   yet at this point.
        vm.expectEmit(true, true, true, false);
        emit ISemaphoreGroups.MembersAdded(groupId, 0, members, 0);

        vm.prank(admin);
        semaphore.addMembers(groupId, members);

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
            8_754_155_586_417_785_722_495_470_355_400_612_435_163_491_722_543_495_943_821_566_022_238_250_742_089,
            9_311_277_326_082_450_661_421_961_776_323_317_578_243_683_731_284_276_799_789_402_550_732_654_540_221,
            21_085_626_846_082_214_868_906_508_770_789_165_162_256_682_314_918_488_454_768_199_138_554_866_360_967,
            21_443_185_256_751_033_286_080_864_270_977_332_698_900_979_912_547_135_282_775_393_829_978_819_886_983,
            6_146_766_603_522_887_336_268_534_704_733_943_707_329_586_494_820_302_567_246_261_601_613_119_898_050,
            6_045_075_051_598_445_696_915_996_184_912_833_218_616_283_726_504_301_031_952_692_097_009_324_813_608,
            7_934_176_176_660_057_205_882_670_886_568_952_288_755_193_231_800_611_293_588_747_925_476_169_302_192,
            13_153_394_304_570_492_498_284_582_612_982_233_846_934_220_238_727_913_230_903_336_758_335_153_705_366
        ];

        ISemaphore.SemaphoreProof memory goodProof = ISemaphore.SemaphoreProof({
            merkleTreeDepth: merkleTreeDepth,
            merkleTreeRoot: merkleTreeRoot,
            // solhint-disable-next-line max-line-length
            nullifier: 9_258_620_728_367_181_689_082_100_997_241_864_348_984_639_649_085_246_237_074_656_141_003_522_567_612,
            // solhint-disable-next-line max-line-length
            message: 32_745_724_963_520_459_128_167_607_516_703_083_632_076_522_816_298_193_357_160_756_506_792_738_947_072,
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

    // function test_ValidateUserOpWhenThresholdIsNotSet() public view {
    //     PackedUserOperation memory userOp = getEmptyUserOperation();
    //     userOp.sender = address(this);
    //     bytes32 userOpHash = keccak256("userOpHash");
    //     uint256 validationData = ERC7579ValidatorBase.ValidationData.unwrap(
    //         semaphoreValidator.validateUserOp(userOp, userOpHash)
    //     );

    //     assertEq(validationData, IERC7579Validator.VALIDATION_FAILED);
    // }

    // function test_ValidateUserOpWhenTheUniqueSignaturesAreInvalid()
    //     public
    //     whenThresholdIsSet
    // {
    //     PackedUserOperation memory userOp = getEmptyUserOperation();
    //     userOp.sender = address(this);

    //     bytes32 userOpHash = keccak256("userOpHash");
    //     bytes memory sign1 = signHash(uint256(1), userOpHash);
    //     bytes memory sign2 = signHash($ownerSks[1], userOpHash);
    //     userOp.signature = abi.encodePacked(sign1, sign2);

    //     ERC7579ValidatorBase.ValidationData res = semaphoreValidator.validateUserOp(userOp,
    // userOpHash);
    //     assertEq(ERC7579ValidatorBase.ValidationData.unwrap(res),
    // IERC7579Validator.VALIDATION_FAILED);
    // }

    // function test_ValidateUserOpWhenTheSignaturesAreValid()
    //     public
    //     whenThresholdIsSet
    // {
    //     PackedUserOperation memory userOp = getEmptyUserOperation();
    //     userOp.sender = address(this);

    //     bytes32 userOpHash = keccak256("userOpHash");
    //     bytes memory sign1 = signHash($ownerSks[0], userOpHash);
    //     bytes memory sign2 = signHash($ownerSks[1], userOpHash);
    //     userOp.signature = abi.encodePacked(sign1, sign2);

    //     ERC7579ValidatorBase.ValidationData res = semaphoreValidator.validateUserOp(userOp,
    // userOpHash);
    //     // assertEq(ERC7579ValidatorBase.ValidationData.unwrap(VALIDATION_SUCCESS);

    // }

    // function test_IsValidSignatureWithSenderWhenTheUniqueSignaturesAreGreaterThanThreshold()
    //     public
    //     whenThresholdIsSet
    // {
    //     address sender = address(1);
    //     bytes32 userOpHash = keccak256("userOpHash");
    //     bytes memory sign1 = signHash($ownerSks[0], userOpHash);
    //     bytes memory sign2 = signHash($ownerSks[1], userOpHash);
    //     bytes memory data = abi.encodePacked(sign1, sign2);

    //     bytes4 result = semaphoreValidator.isValidSignatureWithSender(sender, userOpHash, data);
    //     assertEq(result, EIP1271_MAGIC_VALUE);
    // }

    // function test_ValidateSignatureWithDataWhenTheUniqueSignaturesAreGreaterThanThreshold()
    //     public
    //     whenThresholdIsSet
    // {
    //     bytes32 userOpHash = keccak256("userOpHash");

    //     bytes memory sign1 = signHash($ownerSks[0], userOpHash);
    //     bytes memory sign2 = signHash($ownerSks[1], userOpHash);
    //     bytes memory signature = abi.encodePacked(sign1, sign2);
    //     bytes memory data = abi.encode($threshold, $owners);

    //     bool result = semaphoreValidator.validateSignatureWithData(userOpHash, signature, data);
    //     assertTrue(result);
    // }
}
