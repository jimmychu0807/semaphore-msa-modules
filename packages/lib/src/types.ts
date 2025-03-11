import type { Account, Address, Hex } from "viem";
import { Identity } from "@semaphore-protocol/identity";
import { type SmartAccount } from "viem/account-abstraction";
import { type SmartAccountClient } from "permissionless";
import { type Erc7579Actions } from "permissionless/actions/erc7579";

export type SemaphoreProofFix = {
  merkleTreeDepth: bigint;
  merkleTreeRoot: bigint;
  nullifier: bigint;
  message: bigint;
  scope: bigint;
  points: readonly [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint];
};

export type ExtCallCount = {
  to: Address;
  callData: Hex;
  value: bigint;
  count: number;
};

export type User = {
  account: Account;
  identity: Identity;
};

export type Erc7579SmartAccountClient = Erc7579Actions<SmartAccount> & SmartAccountClient;
