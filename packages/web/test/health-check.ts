import { createBundlerClient } from "viem/account-abstraction";
import { http } from "viem";
import { foundry } from "viem/chains";

export async function ensureBundlerIsReady({ bundlerUrl }: {bundlerUrl: string }) {
  const bundlerClient = createBundlerClient({
    chain: foundry,
    transport: http(bundlerUrl),
  });

  while (true) {
    try {
      const chainId = await bundlerClient.getChainId();
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}

export async function ensurePaymasterIsReady({ paymasterUrl }: {paymasterUrl: string }) {
  while (true) {
    try {
      const res = await fetch(`${paymasterUrl}/ping`);
      const data = await res.json();
      if (data.message !== "pong") throw new Error("paymaster not ready yet");
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}
