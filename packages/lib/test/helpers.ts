import {
  type Abi,
  type Chain,
  type Hex,
  createPublicClient,
  createWalletClient,
  parseEventLogs,
  http,
  getAddress,
} from "viem";

import { type UserOperationReceipt } from "viem/account-abstraction";

import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { Identity } from "@semaphore-protocol/identity";
import debug from "debug";

import type { User } from "@/lib/semaphore-modules/types";
import type { ParsedLog } from "./types";

const info = debug("test:helpers");

export async function transferTo(
  sk: string,
  address: string,
  amt: bigint,
  thresholdpc: number,
  opt: { chain: Chain; rpcUrl: string }
) {
  const { chain, rpcUrl } = opt;
  const parsedAddr = getAddress(address);

  const publicClient = createPublicClient({ chain, transport: http(rpcUrl) });
  const bal = await publicClient.getBalance({ address: parsedAddr });
  const threshold = (amt * BigInt(thresholdpc * 100)) / BigInt(100);
  if (bal >= threshold) {
    info(`${parsedAddr} bal: ${bal} > ${threshold}, skip transfer`);
    return;
  }

  const account = privateKeyToAccount(sk as Hex);
  const client = createWalletClient({ account, chain, transport: http(rpcUrl) });
  const tx = { account, to: parsedAddr, value: amt };
  const hash = await client.sendTransaction(tx);
  info(`transferred ${amt} to ${parsedAddr}: ${hash}`);
}

export function initUsers(userLen: number, firstSk: Hex): User[] {
  const users: User[] = [];

  for (let i = 0; i < userLen; i++) {
    const sk = i === 0 && firstSk !== "0x" ? firstSk : generatePrivateKey();
    users.push({
      account: privateKeyToAccount(sk),
      identity: new Identity(`user-${i}`),
    });
  }

  return users;
}

export function getUserCommitmentsSorted(users: User[]): Array<bigint> {
  return users.map((u) => u.identity.commitment).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}

export function printUserOpReceipt(receipt: UserOperationReceipt, abis: Abi[], bPrintReceipt: boolean = false) {
  const printLogs = (logs: typeof receipt.logs) => {
    const parsedLogs = abis.reduce(
      (acc, abi) => acc.concat(parseEventLogs({ abi, logs, strict: false })),
      [] as ParsedLog[]
    );

    parsedLogs.forEach((log) => {
      if (log.eventName === undefined) return;

      info(`  event: ${log.eventName}, index: ${log.logIndex}`);
      Object.keys(log.args).forEach((arg) => {
        info(`    - ${arg}: ${(log.args as Record<string, string>)[arg]}`);
      });
    });
  };

  info("-- receipt --");
  if (bPrintReceipt) info(`receipt:`, receipt);
  info("  userOpHash:", receipt.userOpHash);
  info("  txHash:", receipt.receipt.transactionHash);
  info("  cumulativeGasUsed:", receipt.receipt.cumulativeGasUsed);
  info("  sender:", receipt.sender);
  info("  nonce:", receipt.nonce);
  info("  total events [userOpReceipt, txReceipt]:", [receipt.logs.length, receipt.receipt.logs.length]);
  printLogs(receipt.receipt.logs);
}
