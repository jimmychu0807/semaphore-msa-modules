import { createPimlicoClient } from "permissionless/clients/pimlico";
import { createPaymasterClient, entryPoint07Address } from "viem/account-abstraction";
import { http, cookieStorage, createConfig, createStorage } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { injected } from "wagmi/connectors";
import { formatEther as viemFormatEther } from "viem";

export const accountSaltNonce = BigInt(process.env.NEXT_PUBLIC_ACCOUNT_SALT_NONCE || 0);
export const pimlicoBaseSepoliaUrl = `https://api.pimlico.io/v2/${baseSepolia.id}/rpc?apikey=${process.env.NEXT_PUBLIC_PIMLICO_API_KEY}`;

export const ethRpcUrl = process.env.NEXT_PUBLIC_ETH_RPC_URL;
export const bundlerUrl = process.env.NEXT_PUBLIC_BUNDLER_URL;
export const paymasterUrl = process.env.NEXT_PUBLIC_PAYMASTER_URL;

// TODO: change back when deploying on BaseSepolia
// export const ethRpcUrl = "https://sepolia.base.org";
// export const bundlerUrl = pimlicoBaseSepoliaUrl;
// export const paymasterUrl = pimlicoBaseSepoliaUrl;

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
