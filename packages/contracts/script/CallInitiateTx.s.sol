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

    address internal to = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    uint256 internal value = 0.001 ether;

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
            merkleTreeDepth: 2,
            merkleTreeRoot: 19442744093851139833491856877150631601462766672436657078470802402477272311750,
            nullifier: 20541180284997122252541791879622537984892190326443056248054559447009152568849,
            message: 4098837972866227347292074301129127878226594423818771086529359030307617999515,
            scope: 0,
            points: [
            16883732984073721500651481105841915112290501106056046116553081732978239328810,
            18807977117082408008175031580734901305523907089474317413204722895825399790855,
            16418007877191788126245963001173058438781116404047503459007172911409094755512,
            17300025513279533823944408548081973535506486707388568440396933333834098163516,
            20880395087229850923488805370436946656808345831405436468458776861134881342431,
            1825494795606795560856122547039044360456300756589434806560656659254307226841,
            2534800793409889541862481084870869961576775879790942234756573461532649983895,
            21195273501837882491463653823178794171167511401766948389555842179617247701496
            ]
        });

        bytes32 txHash = semaphoreExecutor.initiateTx(to, value, "", proof, false);

        console.log("txHash:");
        console.logBytes32(txHash);
    }
}
