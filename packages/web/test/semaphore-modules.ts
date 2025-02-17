import {
  type Account,
  type Chain,
  type Hex,
  type PublicClient,
  createPublicClient,
  encodeFunctionData,
  http,
  parseEther,
} from "viem";
import { createPaymasterClient, entryPoint07Address, getUserOperationHash } from "viem/account-abstraction";

import { type SmartAccountClient, createSmartAccountClient } from "permissionless";
import { getAccountNonce } from "permissionless/actions";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { toSafeSmartAccount } from "permissionless/accounts";
import { erc7579Actions } from "permissionless/actions/erc7579";

import {
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
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

import { type User } from "./types";
import { getTxHash, getUserCommitmentsSorted, initUsers, signMessage, transferTo } from "./helpers";

// const SAFE_ACCT_ADDR = "0x0A8905B6EF15f24901e5D74Cfa68118E69A8Cc63";
const INIT_TRANSFER_AMT = undefined; // In ETH
const TEST_TRANSFER_AMT = parseEther("0.001"); // In ETH
const USER_LEN = 3;
const THRESHOLD = 2;

const info = debug("test:semaphore-modules");

export default async function main({
  deployerSk,
  bundlerUrl,
  rpcUrl,
  paymasterUrl,
  chain,
}: {
  deployerSk: Hex;
  bundlerUrl: string;
  rpcUrl: string;
  paymasterUrl: string;
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

  // transfer ETH to the Safe account for further ops
  if (INIT_TRANSFER_AMT) {
    await transferTo(deployerSk, safeAccount.address, INIT_TRANSFER_AMT, { chain, rpcUrl });
  }

  try {
    await installSemaphoreModules({
      users,
      threshold: THRESHOLD,
      account: safeAccount,
      publicClient,
      bundlerClient,
    });
  } catch (err) {
    console.error("safe account install module failed:", err);
    return;
  }

  // Initiating a transfer
  const target = users[0].account;

  // Get the semaphore proof here
  const txHash = getTxHash(
    await getAcctSeqNum({ account: safeAccount, client: publicClient }),
    target.address,
    TEST_TRANSFER_AMT,
    "0x"
  );

  const gId = await getGroupId({ account: safeAccount, client: publicClient });
  if (!gId) throw new Error("getGroupId() failed");

  const group = new Group(getUserCommitmentsSorted(users));
  const proof = generateProof(owner.identity, group, txHash, gId);

  const data = encodeFunctionData({
    functionName: "initiateTx",
    abi: semaphoreExecutorABI,
    args: [target.address, TEST_TRANSFER_AMT, "0x", proof, false],
  });

  const initTxAction = {
    to: SEMAPHORE_EXECUTOR_ADDRESS,
    target: SEMAPHORE_EXECUTOR_ADDRESS,
    value: 0,
    callData: data,
    data,
  };

  // get account nonce
  const nonce = await getAccountNonce(publicClient, {
    address: safeAccount.address,
    entryPointAddress: entryPoint07Address,
  });

  const initTxOp = await bundlerClient.prepareUserOperation({
    account: safeAccount,
    calls: [initTxAction],
    nonce,
  });

  const opHashToSign = getUserOperationHash({
    chainId: chain.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: "0.7",
    userOperation: initTxOp,
  });

  initTxOp.signature = signMessage(owner, opHashToSign);

  const initTxOpHash = await bundlerClient.sendUserOperation(initTxOp);
  info(`initTxOpHash: ${initTxOpHash}`);

  const receipt = await bundlerClient.waitForUserOperationReceipt({
    hash: initTxOpHash,
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
  account: Account;
  publicClient: PublicClient;
  bundlerClient: SmartAccountClient;
}) {
  // Check if we need to install SemaphoreExecutor module
  // Commitments cannot include 1n, that is the SENTINEL value!!
  const semaphoreCommitments = getUserCommitmentsSorted(users);

  const semaphoreExecutor = await getSemaphoreExecutor({
    threshold,
    semaphoreCommitments,
  });

  let isInstalled: boolean = await isModuleInstalled({
    client: publicClient,
    account,
    module: semaphoreExecutor,
  });

  if (!isInstalled) {
    info("Installing Semaphore Executor...");

    const opHash = await bundlerClient.installModule(semaphoreExecutor);
    info("  L opHash:", opHash);

    const receipt = await bundlerClient.waitForUserOperationReceipt({ hash: opHash });
    info("  L receipt:", receipt);
  }

  // Check if we need to insatll SemaphoreValidator module
  const semaphoreValidator = await getSemaphoreValidator();

  isInstalled = await isModuleInstalled({
    client: publicClient,
    account,
    module: semaphoreValidator,
  });

  if (!isInstalled) {
    info("Installing Semaphore Validator...");

    const opHash = await bundlerClient.installModule(semaphoreValidator);
    info("  L opHash:", opHash);

    const receipt = await bundlerClient.waitForUserOperationReceipt({ hash: opHash });
    info("  L receipt:", receipt);
  }
}
