import {
  type Chain,
  type Hex,
  type PublicClient,
  createPublicClient,
  encodeFunctionData,
  http,
  parseEther,
} from "viem";
import {
  type SmartAccount,
  type UserOperation,
  createPaymasterClient,
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";
import { type UnionPartialBy } from "viem";

import { type SmartAccountClient, createSmartAccountClient } from "permissionless";
// import { getAccountNonce } from "permissionless/actions";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { toSafeSmartAccount } from "permissionless/accounts";
import { getAccountNonce } from "permissionless/actions";
import { erc7579Actions } from "permissionless/actions/erc7579";

import {
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
  encodeValidatorNonce,
  getAccount,
  isModuleInstalled,
} from "@rhinestone/module-sdk";

import {
  getSemaphoreExecutor,
  getSemaphoreValidator,
  SEMAPHORE_EXECUTOR_ADDRESS,
  semaphoreExecutorABI,
  getAcctSeqNum,
  getGroupId,
} from "@/lib/semaphore-modules";
import { Group } from "@semaphore-protocol/group";
import { generateProof } from "@semaphore-protocol/proof";

import { debug } from "debug";

import { type Erc7579SmartAccountClient, type User } from "./types";
import { getTxHash, getUserCommitmentsSorted, initUsers, signMessage, transferTo } from "./helpers";

const INIT_TRANSFER_AMT: bigint = parseEther("0.01"); // In ETH
const TEST_TRANSFER_AMT: bigint = parseEther("0.001"); // In ETH
const USER_LEN: number = 3;
const THRESHOLD: number = 2;

const info = debug("test:semaphore-modules");

export default async function main({
  deployerSk,
  bundlerUrl,
  rpcUrl,
  paymasterUrl,
  saltNonce,
  chain,
}: {
  deployerSk: Hex;
  bundlerUrl: string;
  rpcUrl: string;
  paymasterUrl: string;
  saltNonce: bigint;
  chain: Chain;
}) {
  const users: User[] = initUsers(USER_LEN, deployerSk);

  const owner = users[0];
  info("owner account:", owner.account.address);

  // viem public client
  const publicClient = createPublicClient({
    transport: http(rpcUrl),
    chain,
  });

  // paymaster client
  const paymasterClient = createPaymasterClient({
    transport: http(paymasterUrl),
  });

  // pimlico client
  const pimlicoClient = createPimlicoClient({
    transport: http(bundlerUrl),
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
  });

  // Create Safe smart account
  const safeAccount = await toSafeSmartAccount({
    client: publicClient,
    saltNonce,
    owners: [owner.account],
    version: "1.4.1",
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
    safe4337ModuleAddress: "0x7579EE8307284F293B1927136486880611F20002",
    erc7579LaunchpadAddress: "0x7579011aB74c46090561ea277Ba79D510c6C00ff",
    attesters: [
      RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
      MOCK_ATTESTER_ADDRESS,
    ],
    attestersThreshold: 1,
  });
  info("Safe account:", safeAccount.address);

  // bundler client
  const bundlerClient = createSmartAccountClient({
    account: safeAccount,
    chain,
    bundlerTransport: http(bundlerUrl),
    paymaster: paymasterClient,
    userOperation: {
      estimateFeesPerGas: async () => (await pimlicoClient.getUserOperationGasPrice()).fast,
    },
  }).extend(erc7579Actions());

  // rhinestone account
  const rhinestoneAcct = await getAccount({
    address: safeAccount.address,
    type: "safe",
  });

  // transfer ETH to the Safe account for further ops
  if (INIT_TRANSFER_AMT) {
    await transferTo(deployerSk, safeAccount.address, INIT_TRANSFER_AMT, 0.8, { chain, rpcUrl });
  }

  try {
    await installSemaphoreModules({
      users,
      threshold: THRESHOLD,
      account: safeAccount,
      publicClient,
      bundlerClient: bundlerClient as unknown as Erc7579SmartAccountClient,
    });
  } catch (err) {
    console.error("safe account install module failed:", err);
    return;
  }

  // Initiating a transfer
  const target = users[0].account;

  // Get the semaphore proof here
  const seq = await getAcctSeqNum({ account: safeAccount, client: publicClient });
  info(`acct seq #: ${seq}`);

  const txHash = getTxHash(seq, target.address, TEST_TRANSFER_AMT, "0x");
  info(`txHash: ${txHash}`);

  const gId = await getGroupId({ account: safeAccount, client: publicClient });
  if (gId === undefined) throw new Error("getGroupId() failed");
  info(`gId: ${gId}`);

  const group = new Group(getUserCommitmentsSorted(users));
  info("group merkleRoot:", group.root);

  const proof = await generateProof(owner.identity, group, txHash, gId as bigint);
  info(`proof:`, proof);

  const data = encodeFunctionData({
    functionName: "initiateTx",
    abi: semaphoreExecutorABI,
    args: [target.address, TEST_TRANSFER_AMT, "", proof, false],
  });

  // Refer to rhinestone impl: https://github.com/rhinestonewtf/module-sdk/blob/55b67b57eaf56ff11a7229396bb761eb7994e756/src/module/ownable-executor/usage.ts#L75
  const initTxAction = {
    to: SEMAPHORE_EXECUTOR_ADDRESS,
    target: SEMAPHORE_EXECUTOR_ADDRESS,
    value: 0n,
    callData: data,
    data,
  };

  // Check if we need to insatll SemaphoreValidator module
  const semaphoreValidator = await getSemaphoreValidator();

  const initTxNonce = await getAccountNonce(publicClient, {
    address: safeAccount.address,
    entryPointAddress: entryPoint07Address,
    key: encodeValidatorNonce({ account: rhinestoneAcct, validator: semaphoreValidator }),
  });
  info("initTxNonce:", initTxNonce);

  const initTxOp = await bundlerClient.prepareUserOperation({
    account: safeAccount,
    calls: [initTxAction],
    callGasLimit: BigInt(2e7),
    verificationGasLimit: BigInt(2e7),
  });

  // Include nonce only after performing prepareUserOperation()
  initTxOp.nonce = initTxNonce;

  const opHashToSign = getUserOperationHash({
    chainId: chain.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: "0.7",
    userOperation: initTxOp,
  });
  info("opHashToSign:", opHashToSign);

  initTxOp.signature = signMessage(owner, opHashToSign);
  info("initTxOp.signature:", initTxOp.signature);

  // ERROR: Encountered error
  // Details: User operation gas limits exceed the max gas per bundle: 40080000 > 10000000
  // UserOp hash: 0x8a4976eed5ef52a31c0070033dc40a88e8077c06218073caa929969980ca18f2
  const initTxTxHash = await bundlerClient.sendUserOperation(initTxOp);
  info(`initTxTxHash: ${initTxTxHash}`);

  const receipt = await bundlerClient.waitForUserOperationReceipt({
    hash: initTxTxHash,
  });
  info("receipt:", receipt);
}

async function installSemaphoreModules({
  users,
  threshold,
  account,
  publicClient,
  bundlerClient,
}: {
  users: User[];
  threshold: number;
  account: SmartAccount;
  publicClient: PublicClient;
  bundlerClient: Erc7579SmartAccountClient;
}) {
  // Check if we need to install SemaphoreExecutor module
  // Commitments cannot include 1n, that is the SENTINEL value!!
  const semaphoreCommitments = getUserCommitmentsSorted(users);

  const semaphoreExecutor = await getSemaphoreExecutor({
    threshold,
    semaphoreCommitments,
  });

  // Switch to use rhinestone module-sdk here
  const rhinestoneAcct = await getAccount({
    address: account.address,
    type: "safe",
  });

  let isInstalled: boolean = await isModuleInstalled({
    client: publicClient,
    account: rhinestoneAcct,
    module: semaphoreExecutor,
  });
  info(`semaphoreExecutor is${isInstalled ? "" : " not"} installed`);

  if (!isInstalled) {
    info("Installing Semaphore Executor...");

    const opHash = await bundlerClient.installModule(semaphoreExecutor);
    info("  L opHash:", opHash);

    const receipt = await (bundlerClient as unknown as SmartAccountClient).waitForUserOperationReceipt({
      hash: opHash,
    });
    info("  L receipt:", receipt);
  }

  // Check if we need to insatll SemaphoreValidator module
  const semaphoreValidator = await getSemaphoreValidator();

  isInstalled = await isModuleInstalled({
    client: publicClient,
    account: rhinestoneAcct,
    module: semaphoreValidator,
  });
  info(`semaphoreValidator is${isInstalled ? "" : " not"} installed`);

  if (!isInstalled) {
    info("Installing Semaphore Validator...");

    const opHash = await bundlerClient.installModule(semaphoreValidator);
    info("  L opHash:", opHash);

    const receipt = await bundlerClient.waitForUserOperationReceipt({ hash: opHash });
    info("  L receipt:", receipt);
  }
}
