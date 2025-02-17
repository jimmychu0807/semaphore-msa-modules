import { type Account } from "viem";
import { Identity } from "@semaphore-protocol/identity";

export type User = {
  account: Account,
  identity: Identity
};
