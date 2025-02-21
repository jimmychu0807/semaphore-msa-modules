import type { Abi, Account, GetEventArgs, Log } from "viem";
import { Identity } from "@semaphore-protocol/identity";
import { type SmartAccount } from "viem/account-abstraction";
import { type SmartAccountClient } from "permissionless";
import { type Erc7579Actions } from "permissionless/actions/erc7579";

export type User = {
  account: Account;
  identity: Identity;
};

export type Erc7579SmartAccountClient = Erc7579Actions<SmartAccount> & SmartAccountClient;

export type SemaphoreProofFix = {
  merkleTreeDepth: bigint;
  merkleTreeRoot: bigint;
  nullifier: bigint;
  message: bigint;
  scope: bigint;
  points: readonly [bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint];
};

export type ParsedLog = Log & {
  eventName: string | undefined;
  args: GetEventArgs<
    Abi,
    string,
    {
      EnableUnion: false;
      IndexedOnly: false;
      Required: boolean;
    }
  >;
  logIndex: number;
};
