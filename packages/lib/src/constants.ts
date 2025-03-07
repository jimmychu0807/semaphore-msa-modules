import { type Address, type Hex } from "viem";
import "dotenv/config";

export const SEMAPHORE_EXECUTOR_ADDRESS = (process.env.SEMAPHORE_EXECUTOR_ADDRESS ??
  process.env.NEXT_PUBLIC_SEMAPHORE_EXECUTOR_ADDRESS) as Address;
export const SEMAPHORE_VALIDATOR_ADDRESS = (process.env.SEMAPHORE_VALIDATOR_ADDRESS ??
  process.env.NEXT_PUBLIC_SEMAPHORE_VALIDATOR_ADDRESS) as Address;
export const MOCK_SIG_P2 =
  "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" as Hex;
