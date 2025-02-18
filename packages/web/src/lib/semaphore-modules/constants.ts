import { type Address } from "viem";
import "dotenv/config";

export const SEMAPHORE_EXECUTOR_ADDRESS = process.env.SEMAPHORE_EXECUTOR_ADDRESS as Address;
export const SEMAPHORE_VALIDATOR_ADDRESS = process.env.SEMAPHORE_VALIDATOR_ADDRESS as Address;
