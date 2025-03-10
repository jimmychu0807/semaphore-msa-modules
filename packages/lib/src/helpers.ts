import debug from "debug";
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
import { MOCK_SIG_P2 } from "./constants";
import { getValidatorNonce } from "./usage";

const info = debug("lib:helpers");

export function signMessage(signer: Identity, hash: Hex) {
  const pk = signer.publicKey;
  const signature = signer.signMessage(hash);

  return encodePacked(["uint256[2]", "uint256[2]", "uint256"], [pk, signature.R8, signature.S]);
}

export function mockSignature(signer: Identity) {
  const pk = signer.publicKey;
  return encodePacked(["uint256[2]", "bytes"], [pk, MOCK_SIG_P2]);
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

  // TODO: explore how to set nonce and signature after prepareUserOp while going thru the
  //   prepareUserOp -> getUserOperationHash -> sendUserOperation flow,
  //   so avoid using mock signature in prepareUserOperation().
  const userOp = (await bundlerClient.prepareUserOperation({
    account,
    calls: [action],
    nonce,
    signature: mockSignature(signer),
    callGasLimit: BigInt(2e6),
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
  info(`userOp txHash: ${userOpTxHash}`);

  return await bundlerClient.waitForUserOperationReceipt({ hash: userOpTxHash });
}
