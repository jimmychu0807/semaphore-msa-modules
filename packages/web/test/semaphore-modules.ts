import { debug } from "debug";
import { expect } from "chai";
import {
  type Address,
  type Abi,
  type Chain,
  type Hex,
  type PublicClient,
  createPublicClient,
  http,
  parseEther,
} from "viem";
import { type SmartAccount, createPaymasterClient, entryPoint07Address } from "viem/account-abstraction";

import { type SmartAccountClient, createSmartAccountClient } from "permissionless";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { toSafeSmartAccount } from "permissionless/accounts";
import { erc7579Actions } from "permissionless/actions/erc7579";

import {
  type Module,
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
  getAccount,
  isModuleInstalled,
} from "@rhinestone/module-sdk";
import { Group } from "@semaphore-protocol/group";
import { generateProof } from "@semaphore-protocol/proof";

import {
  getAcctSeqNum,
  getSemaphoreExecutor,
  getSemaphoreValidator,
  getInitTxAction,
  getSignTxAction,
  getExecuteTxAction,
  sendSemaphoreTransaction,
} from "@/lib/semaphore-modules";
import type { Erc7579SmartAccountClient, SemaphoreProofFix, User } from "@/lib/semaphore-modules/types";
import { getTxHash } from "@/lib/semaphore-modules/helpers";
import { semaphoreABI, semaphoreExecutorABI, semaphoreValidatorABI } from "@/lib/semaphore-modules/abi";

import { TestProcess } from "./types";

import { getUserCommitmentsSorted, initUsers, printUserOpReceipt, transferTo } from "./helpers";

const INIT_TRANSFER_AMT: bigint = parseEther("0.01"); // In ETH
const TEST_TRANSFER_AMT: bigint = parseEther("0.001"); // In ETH
const USER_LEN: number = 3;
const THRESHOLD: number = 2;
const TEST_PROCESS: TestProcess = TestProcess.RunInitSignExecute;

const info = debug("test:semaphore-modules");
const projectABIs = [semaphoreABI, semaphoreExecutorABI, semaphoreValidatorABI] as Abi[];

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
    console.error("safe account install modules failed:", err);
    return;
  }

  if (TEST_PROCESS < TestProcess.RunInit) return;

  let txHash;
  try {
    txHash = await initTx({
      signer: owner,
      group: users,
      to: users[0].account.address,
      value: TEST_TRANSFER_AMT,
      account: safeAccount,
      publicClient,
      bundlerClient: bundlerClient as unknown as Erc7579SmartAccountClient,
    });
  } catch (err) {
    console.error("initTx failed:", err);
    return;
  }

  if (TEST_PROCESS < TestProcess.RunInitSign) return;

  try {
    await signTx({
      signer: users[1],
      group: users,
      txHash,
      account: safeAccount,
      publicClient,
      bundlerClient: bundlerClient as unknown as Erc7579SmartAccountClient,
    });
  } catch (err) {
    console.error("signTx failed:", err);
    return;
  }

  if (TEST_PROCESS < TestProcess.RunInitSignExecute) return;

  const sender = safeAccount.address;
  const recipient = users[0].account.address;
  const senderBefore = await publicClient.getBalance({ address: sender });
  const recipientBefore = await publicClient.getBalance({ address: recipient });

  try {
    await executeTx({
      signer: users[2],
      group: users,
      txHash,
      account: safeAccount,
      publicClient,
      bundlerClient: bundlerClient as unknown as Erc7579SmartAccountClient,
    });
  } catch (err) {
    console.error("executeTx failed:", err);
  }

  const senderAfter = await publicClient.getBalance({ address: sender });
  const recipientAfter = await publicClient.getBalance({ address: recipient });

  expect(recipientAfter - recipientBefore).to.equal(TEST_TRANSFER_AMT);
  expect(senderBefore - senderAfter).to.equal(TEST_TRANSFER_AMT);
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
  // Commitments cannot include 1n, that is the SENTINEL value!!
  const semaphoreCommitments = getUserCommitmentsSorted(users);
  const semaphoreExecutor = await getSemaphoreExecutor({
    threshold,
    semaphoreCommitments,
  });
  const semaphoreValidator = await getSemaphoreValidator();

  const installSingleModule = async (moduleName: string, module: Module) => {
    const rhinestoneAcct = await getAccount({
      address: account.address,
      type: "safe",
    });

    const isInstalled: boolean = await isModuleInstalled({
      client: publicClient,
      account: rhinestoneAcct,
      module,
    });
    info(`${moduleName} is${isInstalled ? "" : " not"} installed`);

    if (!isInstalled) {
      info(`Installing ${moduleName}...`);

      const opHash = await bundlerClient.installModule(module);
      info("  - opHash:", opHash);

      const receipt = await (bundlerClient as unknown as SmartAccountClient).waitForUserOperationReceipt({
        hash: opHash,
      });
      printUserOpReceipt(receipt, projectABIs);
    }
  };

  await installSingleModule("Semaphore Executor", semaphoreExecutor);
  await installSingleModule("Semaphore Validator", semaphoreValidator);
}

async function initTx({
  signer,
  group,
  to,
  value,
  account,
  publicClient,
  bundlerClient,
}: {
  signer: User;
  group: User[];
  to: Address;
  value: bigint;
  account: SmartAccount;
  publicClient: PublicClient;
  bundlerClient: Erc7579SmartAccountClient;
}) {
  info("✨✨ Initiate Transaction ✨✨");

  // Get the semaphore proof here
  const seq = await getAcctSeqNum({ account, client: publicClient });
  const txHash = getTxHash(seq, to, value, "0x");
  info(`txHash: ${txHash}`);

  const semGroup = new Group(getUserCommitmentsSorted(group));
  info("group merkleRoot:", semGroup.root);

  // The scope is the txHash
  const proof = (await generateProof(signer.identity, semGroup, "approve", txHash)) as unknown as SemaphoreProofFix;
  info(`proof:`, proof);

  const action = getInitTxAction(to, value, "0x", proof, false);
  const receipt = await sendSemaphoreTransaction({
    signer,
    account,
    action,
    publicClient,
    bundlerClient,
  });
  printUserOpReceipt(receipt, projectABIs);

  return txHash;
}

async function signTx({
  signer,
  group,
  txHash,
  account,
  publicClient,
  bundlerClient,
}: {
  signer: User;
  group: User[];
  txHash: Hex;
  account: SmartAccount;
  publicClient: PublicClient;
  bundlerClient: Erc7579SmartAccountClient;
}) {
  info("✨✨ Sign Transaction ✨✨");

  const semGroup = new Group(getUserCommitmentsSorted(group));
  const proof = (await generateProof(signer.identity, semGroup, "approve", txHash)) as unknown as SemaphoreProofFix;
  info(`proof:`, proof);

  const action = getSignTxAction(txHash, proof, false);
  const receipt = await sendSemaphoreTransaction({
    signer,
    account,
    action,
    publicClient,
    bundlerClient,
  });
  printUserOpReceipt(receipt, projectABIs);
}

async function executeTx({
  signer,
  txHash,
  account,
  publicClient,
  bundlerClient,
}: {
  signer: User;
  group: User[];
  txHash: Hex;
  account: SmartAccount;
  publicClient: PublicClient;
  bundlerClient: Erc7579SmartAccountClient;
}) {
  info("✨✨ Execute Transaction ✨✨");

  const action = getExecuteTxAction(txHash);
  const receipt = await sendSemaphoreTransaction({
    signer,
    account,
    action,
    publicClient,
    bundlerClient,
  });
  printUserOpReceipt(receipt, projectABIs);
}
