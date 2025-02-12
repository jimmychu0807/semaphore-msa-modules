import { type Account, type PublicClient, encodePacked } from 'viem';
import { type Module } from '@rhinestone/module-sdk';
import {
  SEMAPHORE_EXECUTOR_ADDRESS,
  SEMAPHORE_VALIDATOR_ADDRESS,
} from "./constants";

type GetSemaphoreExecutorParams = {
  account: Account,
  client: PublicClient,
  threshold: number,
  semaphoreCommitments: Array<bigint>
}

export async function getSemaphoreExecutor({
  account,
  client,
  threshold,
  semaphoreCommitments }: GetSemaphoreExecutorParams): Promise<Module>
{
  return {
    address: SEMAPHORE_EXECUTOR_ADDRESS,
    module: SEMAPHORE_EXECUTOR_ADDRESS,
    type: "executor",
    initData: encodePacked(
      ['uint8','uint256[]'],
      [threshold, semaphoreCommitments]
    ),
    deInitData: '0x',
    additionalContext: '0x',
    hook: undefined
  };
}
