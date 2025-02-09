import { expect } from 'chai';
import { ensureBundlerIsReady, ensurePaymasterIsReady } from "./health-check";
import smartSessionsPermissionlessSafe from "./smart-sessions/permissionless-safe";
import {
  sepolia
} from "viem/chains";

import * as dotenv from "dotenv";
dotenv.config();

const bundlerUrl = process.env.BUNDLER_URL as string;
const paymasterUrl = process.env.PAYMASTER_URL as string;
const rpcUrl = process.env.RPC_URL as string;

describe("Test erc7579 reference implementation", function () {
  before(async function () {
    await ensureBundlerIsReady({ bundlerUrl });
    await ensurePaymasterIsReady({ paymasterUrl });
  });

  it("should test smart sessions with permissionless", async function () {
    const receipt = await smartSessionsPermissionlessSafe({
      bundlerUrl,
      rpcUrl,
      paymasterUrl,
      chain: sepolia
    });

    expect(receipt.success).to.be.true;
  });
});
