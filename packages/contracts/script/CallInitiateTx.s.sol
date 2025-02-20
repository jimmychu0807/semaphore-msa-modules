// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { Identity, IdentityLib } from "../test/utils/TestUtils.sol";
import { User } from "../test/utils/SharedTestSetup.sol";
import { ISemaphore, Semaphore } from "semaphore/Semaphore.sol";
import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { Script, console } from "forge-std/Script.sol";

/* solhint-disable no-console */

contract CallInitiateTx is Script {
    using IdentityLib for Identity;

    Semaphore internal semaphore;
    SemaphoreExecutor internal semaphoreExecutor;
    SemaphoreValidator internal semaphoreValidator;
    User[] internal $users;

    function setUp() public {
        semaphore = Semaphore(vm.envAddress("SEMAPHORE_ADDRESS"));
        semaphoreExecutor = SemaphoreExecutor(vm.envAddress("SEMAPHORE_EXECUTOR_ADDRESS"));
        semaphoreValidator = SemaphoreValidator(vm.envAddress("SEMAPHORE_VALIDATOR_ADDRESS"));
    }

    function run() public {
        console.log("sender: %s", msg.sender);
        vm.startPrank(msg.sender);

        (bool bFound, uint256 gId) = semaphoreExecutor.getGroupId(msg.sender);
        console.log("found: %s | gId: %s", bFound, gId);

        uint256 root = semaphore.getMerkleTreeRoot(gId);
        console.log("merkleTreeRoot: %s", root);

        uint256 size = semaphore.getMerkleTreeSize(gId);
        console.log("merkleTreeSize: %s", size);

        ISemaphore.SemaphoreProof memory proof = ISemaphore.SemaphoreProof({
            merkleTreeDepth: 1,
            merkleTreeRoot: 8_593_273_862_282_316_009_541_347_145_730_787_265_247_558_829_699_280_200_913_137_304_540_994_498_211,
            nullifier: 703_766_378_262_230_293_347_691_962_533_699_164_338_388_539_083_671_341_964_287_077_549_428_774_067,
            message: 1_497_921_421_622_568_031_017_425_378_579_326_729_134_393_587_265_313_026_229_198_760_216_032_645_539,
            scope: 1,
            points: [
                14_701_524_823_354_709_974_144_582_533_763_818_447_716_151_570_445_961_832_970_934_826_690_760_791_777,
                18_078_507_845_826_299_792_700_052_669_827_352_399_705_426_817_403_779_980_232_977_098_014_456_405_892,
                3_199_098_870_392_265_411_433_964_013_742_811_522_223_669_277_396_809_182_638_540_126_484_122_683_531,
                14_373_716_129_466_799_117_738_077_634_416_822_000_931_326_947_336_214_125_660_878_091_372_761_156_509,
                14_368_728_666_905_850_541_173_534_091_088_100_094_557_051_360_977_219_553_924_847_155_533_798_303_220,
                19_820_601_479_875_014_734_075_069_283_952_823_181_349_947_610_129_321_153_131_089_280_965_203_900_216,
                5_343_029_762_374_433_937_467_602_139_775_975_736_719_147_750_707_827_780_735_823_781_848_370_615_739,
                20_220_034_453_063_398_018_895_993_896_400_248_392_820_211_089_268_133_314_844_710_156_141_051_434_089
            ]
        });

        bytes32 txHash = semaphoreExecutor.initiateTx(
            address(0xeB10092a57e4fCb7260e05E4d3d2D29c84339758), 0.001 ether, "", proof, false
        );

        console.log("txHash:");
        console.logBytes32(txHash);
    }
}
