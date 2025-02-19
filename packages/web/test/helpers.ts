import {
  type Address,
  type Chain,
  type Hex,
  createPublicClient,
  createWalletClient,
  encodePacked,
  http,
  getAddress,
  keccak256,
} from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { Identity } from "@semaphore-protocol/identity";
import { debug } from "debug";

import { User } from "./types";

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
  return users.map((u) => u.identity.commitment).sort((a, b) => a < b ? -1 : (a > b ? 1 : 0));
}

export function signMessage(user: User, hash: Hex) {
  const pk = user.identity.publicKey;
  const signature = user.identity.signMessage(hash);

  return encodePacked(["uint256[2]", "uint256[2]", "uint256"], [pk, signature.R8, signature.S]);
}

export function getTxHash(seq: bigint, target: Address, value: bigint, callData: Hex) {
  return keccak256(encodePacked(["uint256", "address", "uint256", "bytes"], [seq, target, value, callData]));
}
