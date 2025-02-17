// import { expect } from 'chai';
import { ensureBundlerIsReady, ensurePaymasterIsReady } from "./health-check";
import TestSemaphoreModules from "./semaphore-modules";
import { type Hex } from "viem";
import { baseSepolia } from "viem/chains";
import "dotenv/config";
import { debug } from "debug";

const info = debug("test:main");

const deployerSk = (process.env.DEPLOYER_SK || "0x") as Hex;
const rpcUrl = process.env.ETH_RPC_URL as string;
const bundlerUrl = process.env.BUNDLER_URL as string;
const paymasterUrl = process.env.PAYMASTER_URL as string;
const chain = baseSepolia;

info("rpcUrl:", rpcUrl);
info("bundlerUrl:", bundlerUrl);
info("paymasterUrl:", paymasterUrl);

describe("Test Semaphore modules", function () {
  before(async function () {
    await ensureBundlerIsReady({ bundlerUrl, chain });

    // This check only work in local mock paymaster
    if (["127.0.0.1", "localhost"].some((v) => paymasterUrl.includes(v))) {
      await ensurePaymasterIsReady({ paymasterUrl });
    }
  });

  it("semaphore modules should work", async function () {
    await TestSemaphoreModules({
      deployerSk,
      bundlerUrl,
      rpcUrl,
      paymasterUrl,
      chain,
    });
  });
});
