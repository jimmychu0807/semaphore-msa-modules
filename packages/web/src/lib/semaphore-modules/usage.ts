import { type Account, type Address, type Hex, type PublicClient, encodeFunctionData } from "viem";

import { type SmartAccount } from "viem/account-abstraction";
import { getAccountNonce } from "permissionless/actions";

import { type Execution, encodeValidatorNonce, getAccount } from "@rhinestone/module-sdk";

import { getSemaphoreValidator } from "./installation";
import { SEMAPHORE_EXECUTOR_ADDRESS } from "./constants";
import { semaphoreExecutorABI } from "./abi";
import type { SemaphoreProofFix } from "./types";

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

export function getInitTxAction(
  to: Address,
  value: bigint,
  callData: Hex,
  proof: SemaphoreProofFix,
  bExecute: boolean
): Execution {
  const data = encodeFunctionData({
    functionName: "initiateTx",
    abi: semaphoreExecutorABI,
    args: [to, value, callData, proof, bExecute],
  });

  // Refer to rhinestone impl: https://github.com/rhinestonewtf/module-sdk/blob/55b67b57eaf56ff11a7229396bb761eb7994e756/src/module/ownable-executor/usage.ts#L75
  return {
    to: SEMAPHORE_EXECUTOR_ADDRESS,
    target: SEMAPHORE_EXECUTOR_ADDRESS,
    value: 0n,
    callData: data,
    data,
  };
}

export function getSignTxAction(txHash: Hex, proof: SemaphoreProofFix, bExecute: boolean): Execution {
  const data = encodeFunctionData({
    functionName: "signTx",
    abi: semaphoreExecutorABI,
    args: [txHash, proof, bExecute],
  });

  return {
    to: SEMAPHORE_EXECUTOR_ADDRESS,
    target: SEMAPHORE_EXECUTOR_ADDRESS,
    value: 0n,
    callData: data,
    data,
  };
}

export function getExecuteTxAction(txHash: Hex): Execution {
  const data = encodeFunctionData({
    functionName: "executeTx",
    abi: semaphoreExecutorABI,
    args: [txHash],
  });

  return {
    to: SEMAPHORE_EXECUTOR_ADDRESS,
    target: SEMAPHORE_EXECUTOR_ADDRESS,
    value: 0n,
    callData: data,
    data,
  };
}

export async function getValidatorNonce(
  account: SmartAccount,
  type: string,
  publicClient: PublicClient
): ReturnType<typeof getAccountNonce> {
  const semaphoreValidator = await getSemaphoreValidator();

  // rhinestone account
  const rhinestoneAcct = await getAccount({
    address: account.address,
    type: "safe",
  });

  return await getAccountNonce(publicClient, {
    address: account.address,
    entryPointAddress: account.entryPoint.address,
    key: encodeValidatorNonce({
      account: rhinestoneAcct,
      validator: semaphoreValidator,
    }),
  });
}
