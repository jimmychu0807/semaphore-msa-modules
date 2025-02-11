import {
  type Chain,
  createPublicClient,
  http
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

import { getSemaphoreExecutor } from "@/lib/semaphore-modules";

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
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
    owners: [owner],
    saltNonce: 0n,
    version: "1.4.1",
    safe4337ModuleAddress: "0x7579EE8307284F293B1927136486880611F20002",
    erc7579LaunchpadAddress: "0x7579011aB74c46090561ea277Ba79D510c6C00ff",
  });

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

  // get the SemaphoreExecutor module
  const semaphoreCommitments: Array<bigint> = [1n, 2n, 3n];

  const semaphoreExecutor = await getSemaphoreExecutor({
    account: safeAccount,
    client: publicClient,
    threshold: 1,
    semaphoreCommitments,
  });

  const opHash1 = await bundlerClient.installModule(semaphoreExecutor);
  console.log("opHash1:", opHash1);

  const receipt1 = await bundlerClient.waitForUserOperationReceipt({ hash: opHash1 });
  console.log("receipt1:", receipt1);
}
