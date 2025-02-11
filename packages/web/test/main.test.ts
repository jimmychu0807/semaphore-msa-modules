import { expect } from 'chai';
import { ensureBundlerIsReady, ensurePaymasterIsReady } from "./health-check";
import TestSemaphoreModules from "./semaphore-modules";
import {
  sepolia
} from "viem/chains";
import 'dotenv/config';

const bundlerUrl = process.env.BUNDLER_URL as string;
const paymasterUrl = process.env.PAYMASTER_URL as string;
const rpcUrl = process.env.ETH_RPC_URL as string;

describe("Test erc7579 reference implementation", function () {
  before(async function () {
    await ensureBundlerIsReady({ bundlerUrl });
    await ensurePaymasterIsReady({ paymasterUrl });
  });

  it("should test smart sessions with permissionless", async function () {
    const receipt = await TestSemaphoreModules({
      bundlerUrl,
      rpcUrl,
      paymasterUrl,
      chain: sepolia
    });

  });
});
