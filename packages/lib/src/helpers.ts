import { type Address, type Hex, type PublicClient, encodePacked, keccak256 } from "viem";

import {
  type SmartAccount,
  type UserOperation,
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";

import { Identity } from "@semaphore-protocol/identity";
import { type Execution } from "@rhinestone/module-sdk";

import { type Erc7579SmartAccountClient } from "./types";
import { getValidatorNonce } from "./usage";

export function signMessage(signer: Identity, hash: Hex) {
  const pk = signer.publicKey;
  const signature = signer.signMessage(hash);

  return encodePacked(["uint256[2]", "uint256[2]", "uint256"], [pk, signature.R8, signature.S]);
}

export function getTxHash(seq: bigint, target: Address, value: bigint, callData: Hex) {
  return keccak256(encodePacked(["uint256", "address", "uint256", "bytes"], [seq, target, value, callData]));
}

export async function sendSemaphoreTransaction({
  signer,
  account,
  action,
  publicClient,
  bundlerClient,
}: {
  signer: Identity;
  account: SmartAccount;
  action: Execution;
  publicClient: PublicClient;
  bundlerClient: Erc7579SmartAccountClient;
}) {
  const nonce = await getValidatorNonce(account, "safe", publicClient);
  const userOp = (await bundlerClient.prepareUserOperation({
    account,
    calls: [action],
    nonce,
    // note: we set the three gas type here so it doesn't call estimateUserOperationGas and
    //   check for the signature
    callGasLimit: BigInt(2e6),
    preVerificationGas: BigInt(3e5),
    verificationGasLimit: BigInt(6e6),
  })) as UserOperation;

  const userOpHash = getUserOperationHash({
    chainId: publicClient.chain!.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: "0.7",
    userOperation: userOp,
  });
  userOp.signature = signMessage(signer, userOpHash);

  const userOpTxHash = await bundlerClient.sendUserOperation(userOp);

  return await bundlerClient.waitForUserOperationReceipt({ hash: userOpTxHash });
}
