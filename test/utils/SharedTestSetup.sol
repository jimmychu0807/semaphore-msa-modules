// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

// forge-std
import { Test } from "forge-std/Test.sol";

// Rhinestone Modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { LibSort, LibString } from "solady/Milady.sol";

import { SemaphoreExecutor } from "src/SemaphoreExecutor.sol";
import { SemaphoreValidator } from "src/SemaphoreValidator.sol";
import { SemaphoreVerifier } from "semaphore/base/SemaphoreVerifier.sol";
import { ISemaphore, ISemaphoreVerifier, Semaphore } from "semaphore/Semaphore.sol";

import { Identity, IdentityLib, SimpleContract } from "test/utils/TestUtils.sol";
import { NUM_MEMBERS, NUM_USERS } from "test/utils/Constants.sol";

struct User {
    uint256 sk;
    address addr;
    Identity identity;
}

abstract contract SharedTestSetup is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using LibSort for *;
    using IdentityLib for Identity;

    AccountInstance internal smartAcct;
    SemaphoreValidator internal semaphoreValidator;
    SemaphoreExecutor internal semaphoreExecutor;
    SimpleContract internal simpleContract;
    User[] internal $users;

    function setUp() public virtual {
        super.init();

        // Deploy Semaphore
        SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
        vm.label(address(semaphoreVerifier), "SemaphoreVerifier");

        Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
        vm.label(address(semaphore), "Semaphore");

        // Create the executor
        semaphoreExecutor = new SemaphoreExecutor(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreExecutor");

        // Create the validator
        semaphoreValidator = new SemaphoreValidator(semaphoreExecutor);
        vm.label(address(semaphoreValidator), "SemaphoreValidator");

        // Set semaphoreValidator in the executor
        semaphoreExecutor.setSemaphoreValidator(address(semaphoreValidator));

        // Create the smart account
        smartAcct = makeAccountInstance("SmartAccount");
        vm.deal(smartAcct.account, 10 ether);
        vm.label(smartAcct.account, "SmartAccount");

        // Create a few users
        for (uint256 i = 0; i < NUM_USERS; ++i) {
            string memory nickname = string.concat("user", LibString.toString(i + 1));
            (address addr, uint256 sk) = makeAddrAndKey(nickname);
            vm.deal(addr, 5 ether);
            vm.label(addr, nickname);
            $users.push(User({ sk: sk, addr: addr, identity: IdentityLib.genIdentity(i + 1) }));
        }
    }

    /**
     * Modifiers
     */
    modifier setupSmartAcctWithMembersThreshold(uint8 numMembers, uint8 threshold) {
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(semaphoreExecutor),
            data: abi.encodePacked(uint8(threshold), _getMemberCmts(numMembers))
        });

        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: ""
        });

        _;
    }

    modifier deploySimpleContract() {
        simpleContract = new SimpleContract(0);
        _;
    }

    /**
     * Internal helper funcitons
     */
    function _getMemberCmts(uint8 num) internal returns (uint256[] memory cmts) {
        cmts = new uint256[](num);
        for (uint8 i = 0; i < num; ++i) {
            cmts[i] = $users[i].identity.commitment();
        }
        cmts.insertionSort();
    }

    function _getSemaphoreUserOpData(
        Identity id,
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
        userOpData.userOp.signature = id.signHash(userOpData.userOpHash);
    }

    function _setupInitiateTx(
        uint8 numMembers,
        address target,
        uint256 value,
        bytes memory txCallData,
        bool bExecute
    )
        internal
        returns (UserOpData memory userOpData, bytes32 txHash)
    {
        User storage member = $users[0];
        // Compose txHash
        uint256 seq = semaphoreExecutor.getAcctSeqNum(smartAcct.account);
        txHash = keccak256(abi.encodePacked(seq, target, value, txCallData));

        // Compose Semaphore proof
        (, uint256 groupId) = semaphoreExecutor.getGroupId(smartAcct.account);
        ISemaphore.SemaphoreProof memory smProof =
            member.identity.generateSempahoreProof(groupId, _getMemberCmts(numMembers), txHash);

        // Compose UserOpData
        userOpData = _getSemaphoreUserOpData(
            member.identity,
            value,
            abi.encodeCall(SemaphoreExecutor.initiateTx, (target, txCallData, smProof, bExecute))
        );
    }

    function _setupInitiateTxSingleMember(
        address target,
        uint256 value,
        bytes memory txCallData,
        bool bExecute
    )
        internal
        setupSmartAcctWithMembersThreshold(1, 1)
        returns (UserOpData memory userOpData, bytes32 txHash)
    {
        return _setupInitiateTx(1, target, value, txCallData, bExecute);
    }

    function _setupInitiateTxMultiMembers(
        address target,
        uint256 value,
        bytes memory txCallData,
        bool bExecute
    )
        internal
        setupSmartAcctWithMembersThreshold(NUM_MEMBERS, 2)
        returns (UserOpData memory userOpData, bytes32 txHash)
    {
        return _setupInitiateTx(NUM_MEMBERS, target, value, txCallData, bExecute);
    }
}
