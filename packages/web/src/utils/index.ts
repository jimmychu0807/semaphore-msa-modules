import { createPaymasterClient, entryPoint07Address } from "viem/account-abstraction";
import { type Address, type PublicClient, type WalletClient, formatEther as viemFormatEther } from "viem";
import { http, cookieStorage, createConfig, createStorage } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { injected } from "wagmi/connectors";

import { createSmartAccountClient } from "permissionless";
import { toSafeSmartAccount } from "permissionless/accounts";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { erc7579Actions } from "permissionless/actions/erc7579";
import {
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
} from "@rhinestone/module-sdk";

import { AppSmartAccountClient } from "@/types";

export const accountSaltNonce = BigInt(process.env.NEXT_PUBLIC_ACCOUNT_SALT_NONCE || 0);
export const pimlicoBaseSepoliaUrl = `https://api.pimlico.io/v2/${baseSepolia.id}/rpc?apikey=${process.env.NEXT_PUBLIC_PIMLICO_API_KEY}`;

// TODO: change back when deploying on BaseSepolia
// export const ethRpcUrl = "https://sepolia.base.org";
// export const bundlerUrl = pimlicoBaseSepoliaUrl;
// export const paymasterUrl = pimlicoBaseSepoliaUrl;
export const ethRpcUrl = process.env.NEXT_PUBLIC_ETH_RPC_URL;
export const bundlerUrl = process.env.NEXT_PUBLIC_BUNDLER_URL;
export const paymasterUrl = process.env.NEXT_PUBLIC_PAYMASTER_URL;

export function getConfig() {
  return createConfig({
    chains: [baseSepolia],
    connectors: [injected()],
    storage: createStorage({
      storage: cookieStorage,
    }),
    ssr: true,
    transports: {
      [baseSepolia.id]: http(ethRpcUrl),
    },
  });
}

export const pimlicoClient = createPimlicoClient({
  transport: http(bundlerUrl),
  entryPoint: {
    address: entryPoint07Address,
    version: "0.7",
  },
});

export const paymasterClient = createPaymasterClient({
  transport: http(paymasterUrl),
});

export function formatEther(value: bigint, decimal: number = 3): string {
  return Number(viemFormatEther(value)).toFixed(decimal).toString();
}

export async function getSmartAccountClient({
  publicClient,
  saltNonce,
  owners,
  address,
}: {
  publicClient: PublicClient | undefined;
  saltNonce?: bigint;
  owners?: Array<WalletClient>;
  address?: Address;
}): Promise<AppSmartAccountClient> {
  if (!publicClient) throw new Error("publicClient is falsy");
  if (!address && !saltNonce && !owners) throw new Error("not enough data to get a safe account");

  const safeAccount = await toSafeSmartAccount({
    client: publicClient,
    saltNonce,
    owners: owners || [], // note: is it okay to have empty owners?
    address,
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

  const smartAccountClient = createSmartAccountClient({
    account: safeAccount,
    chain: baseSepolia,
    bundlerTransport: http(bundlerUrl),
    paymaster: paymasterClient,
    userOperation: {
      estimateFeesPerGas: async () => (await pimlicoClient.getUserOperationGasPrice()).fast,
    },
  }).extend(erc7579Actions());

  return smartAccountClient as unknown as AppSmartAccountClient;
}

export function getCommitmentsSorted(cmts: bigint[]): Array<bigint> {
  return cmts.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}
