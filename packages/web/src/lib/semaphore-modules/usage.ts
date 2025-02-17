import { type Account, type PublicClient } from "viem";

import { SEMAPHORE_EXECUTOR_ADDRESS } from "./constants";
import { semaphoreExecutorABI } from "./abi";

export async function getAcctSeqNum({ account, client }: { account: Account; client: PublicClient }): Promise<bigint> {
  try {
    const threshold = (await client.readContract({
      address: SEMAPHORE_EXECUTOR_ADDRESS,
      abi: semaphoreExecutorABI,
      functionName: "getAcctSeqNum",
      args: [account.address],
    })) as bigint;

    return threshold;
  } catch {
    throw new Error("Failed to get account sequence number");
  }
}

export async function getGroupId({
  account,
  client,
}: {
  account: Account;
  client: PublicClient;
}): Promise<bigint | undefined> {
  try {
    const res = (await client.readContract({
      address: SEMAPHORE_EXECUTOR_ADDRESS,
      abi: semaphoreExecutorABI,
      functionName: "getGroupId",
      args: [account.address],
    })) as [boolean, bigint];

    return res[0] ? res[1] : undefined;
  } catch {
    throw new Error("Failed to get account group ID");
  }
}
