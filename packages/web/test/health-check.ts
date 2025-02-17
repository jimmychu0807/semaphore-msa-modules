import { createBundlerClient } from "viem/account-abstraction";
import { type Chain, http } from "viem";
import { debug } from "debug";

const info = debug("test:health-check");

export async function ensureBundlerIsReady(
  { bundlerUrl, chain }: { bundlerUrl: string; chain: Chain; }
) {
  info("Checking bundler...");

  const bundlerClient = createBundlerClient({
    chain,
    transport: http(bundlerUrl),
  });

  while (true) {
    try {
      const chainId = await bundlerClient.getChainId();
      info(`  L good: ${chainId}`);
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}

export async function ensurePaymasterIsReady({ paymasterUrl }: {paymasterUrl: string }) {
  info("Checking paymaster...");

  while (true) {
    try {
      const res = await fetch(`${paymasterUrl}/ping`);
      const data = await res.json();
      if (data.message !== "pong") throw new Error("paymaster not ready yet");
      info("  L good");
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}
