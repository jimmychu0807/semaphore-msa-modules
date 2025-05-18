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

  console.log("100");

  // We fill in all the gas to avoid estimateUserOperationGas being called:
  // https://github.com/wevm/viem/blob/5d9bdabd61a95a22a914c78c242fa9cfbc803ed1/src/account-abstraction/actions/bundler/prepareUserOperation.ts#L614-L620

  const userOp = (await bundlerClient.prepareUserOperation({
    account,
    calls: [action],
    nonce,
    // note: we set the three gas type here so it doesn't call estimateUserOperationGas and
    //   check for the signature
    callGasLimit: BigInt(2e6),
    preVerificationGas: BigInt(3e5),
    // note: we will run signature verfication and require lots of gas. Set the following to
    // ensure we have enough gas.
    verificationGasLimit: BigInt(1e7),
    paymasterPostOpGasLimit: BigInt(2e6),
    paymasterVerificationGasLimit: BigInt(2e6),
    maxFeePerGas: BigInt(1e6),
    maxPriorityFeePerGas: BigInt(1e6),
  })) as UserOperation;

  console.log("200");

  // userOp.nonce = nonce;

  let userOpHash = getUserOperationHash({
    chainId: publicClient.chain!.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: "0.7",
    userOperation: userOp,
  });
  userOp.signature = signMessage(signer, userOpHash);

  // console.log("userOpHash 1:", userOpHash);
  // console.log("userOp 1:", userOp);

  // const paymasterArgs = await paymasterClient.getPaymasterData({
  //   callData: userOp.callData,
  //   nonce: userOp.nonce,
  //   sender: userOp.sender,
  //   signature: userOp.signature,
  //   chainId: publicClient.chain!.id,
  //   entryPointAddress: entryPoint07Address,
  //   maxFeePerGas: userOp.maxFeePerGas,
  //   maxPriorityFeePerGas: userOp.maxPriorityFeePerGas,
  //   preVerificationGas: userOp.preVerificationGas,
  //   verificationGasLimit: userOp.verificationGasLimit,
  // });

  // console.log("paymasterArgs:", paymasterArgs);

  // // 1. integrate the paymasterArgs into userOp
  // userOp.paymaster = paymasterArgs.paymaster;
  // userOp.paymasterData = paymasterArgs.paymasterData

  // 2. get the userOpHash again. Is it the same as the userOphash above
  // userOpHash = getUserOperationHash({
  //   chainId: publicClient.chain!.id,
  //   entryPointAddress: entryPoint07Address,
  //   entryPointVersion: "0.7",
  //   userOperation: userOp,
  // });
  // userOp.signature = signMessage(signer, userOpHash);

  // console.log("userOpHash 2:", userOpHash);
  // console.log("userOp signature:", userOp.signature);

  // 3. sign again with paymasterArgs

  console.log("300");

  const userOpTxHash = await bundlerClient.sendUserOperation(userOp);
  const receipt = await bundlerClient.waitForUserOperationReceipt({ hash: userOpTxHash });

  console.log("400");

  if (!receipt.success) {
    throw Error(`userOp transaction failed with reason: ${receipt.reason}`, { cause: receipt });
  }

  return receipt;
}
