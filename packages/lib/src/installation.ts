import { encodePacked } from "viem";
import { type Module } from "@rhinestone/module-sdk";
import { SEMAPHORE_EXECUTOR_ADDRESS, SEMAPHORE_VALIDATOR_ADDRESS } from "./constants";

type GetSemaphoreExecutorParams = {
  threshold: number;
  semaphoreCommitments: Array<bigint>;
};

export function getSemaphoreExecutor({ threshold, semaphoreCommitments }: GetSemaphoreExecutorParams): Module {
  return {
    address: SEMAPHORE_EXECUTOR_ADDRESS,
    module: SEMAPHORE_EXECUTOR_ADDRESS,
    type: "executor",
    initData: encodePacked(["uint8", "uint256[]"], [threshold, semaphoreCommitments]),
    deInitData: "0x",
    additionalContext: "0x",
    hook: undefined,
  };
}

export function getSemaphoreValidator(): Module {
  return {
    address: SEMAPHORE_VALIDATOR_ADDRESS,
    module: SEMAPHORE_VALIDATOR_ADDRESS,
    type: "validator",
    initData: "0x",
    deInitData: "0x",
    additionalContext: "0x",
  };
}
