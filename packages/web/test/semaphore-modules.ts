import {
  type Chain,
  createPublicClient,
  createWalletClient,
  getAddress,
  http,
  parseEther,
} from "viem";
import {
  createPaymasterClient,
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

import { createSmartAccountClient } from "permissionless";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { toSafeSmartAccount } from "permissionless/accounts";
import { erc7579Actions } from "permissionless/actions/erc7579";

import {
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
  getDeadmanSwitch,
  getAccount,
  getClient
} from "@rhinestone/module-sdk";

import { getSemaphoreExecutor } from "@/lib/semaphore-modules";

const TEST_SK = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

export default async function main({
  bundlerUrl,
  rpcUrl,
  paymasterUrl,
  chain,
}: {
  bundlerUrl: string;
  rpcUrl: string;
  paymasterUrl: string;
  chain: Chain
}) {
  // EOAs
  const owner = privateKeyToAccount(generatePrivateKey());
  const user1 = privateKeyToAccount(generatePrivateKey());
  const user2 = privateKeyToAccount(generatePrivateKey());
  const user3 = privateKeyToAccount(generatePrivateKey());

  // viem public client
  const publicClient = createPublicClient({
    transport: http(rpcUrl),
    chain
  });

  // paymaster client
  const paymasterClient = createPaymasterClient({
    transport: http(paymasterUrl)
  })

  // pimlico client
  const pimlicoClient = createPimlicoClient({
    transport: http(bundlerUrl),
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    }
  });

  // Safe smart account
  const safeAccount = await toSafeSmartAccount({
    client: publicClient,
    owners: [owner],
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

  console.log("safe account:", safeAccount.address);

  // bundler client
  const bundlerClient = createSmartAccountClient({
    account: safeAccount,
    chain,
    bundlerTransport: http(bundlerUrl),
    paymaster: paymasterClient,
    userOperation: {
      estimateFeesPerGas: async() => (await pimlicoClient.getUserOperationGasPrice()).fast,
    }
  }).extend(erc7579Actions());

  // transfer 10 ETH to the Safe account
  await transferTo(safeAccount.address, "10", { chain, rpcUrl });

  // get the SemaphoreExecutor module
  const semaphoreCommitments: Array<bigint> = [1n, 2n, 3n];

  const semaphoreExecutor = await getSemaphoreExecutor({
    account: safeAccount,
    client: publicClient,
    threshold: 1,
    semaphoreCommitments,
  });

  console.log("semaphoreExecutor:", semaphoreExecutor);

  const account = getAccount({
    address: safeAccount.address,
    type: "safe",
  });

  const client = getClient({
    rpcUrl,
  });

  const deadmanSwitch = await getDeadmanSwitch({
    account,
    client,
    nominee: user1.address,
    timeout: 1,
    moduleType: "validator",
  });
  console.log("deadman switch:", deadmanSwitch);

  const opHash1 = await bundlerClient.installModule(semaphoreExecutor);
  console.log("opHash1:", opHash1);

  // const receipt1 = await bundlerClient.waitForUserOperationReceipt({ hash: opHash1 });

  // console.log("receipt1:", receipt1);
}

async function transferTo(address: string, ethBal: string, opt: { chain: Chain, rpcUrl: string }) {
  const account = privateKeyToAccount(TEST_SK);
  const client = createWalletClient({
    account,
    chain: opt.chain,
    transport: http(opt.rpcUrl)
  });

  const parsedAddr = getAddress(address);

  const tx = {
    account,
    to: parsedAddr,
    value: parseEther(ethBal)
  };

  const hash = await client.sendTransaction(tx);
  console.log(`sent ${ethBal} ETH to ${address}: ${hash}`);
}
