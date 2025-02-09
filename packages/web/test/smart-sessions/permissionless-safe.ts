import {
  type Session,
  encodeSmartSessionSignature,
  encodeValidationData,
  encodeValidatorNonce,
  getAccount,
  getOwnableValidator,
  getOwnableValidatorMockSignature,
  getPermissionId,
  getSmartSessionsValidator,
  getSudoPolicy,
  OWNABLE_VALIDATOR_ADDRESS,
  RHINESTONE_ATTESTER_ADDRESS,
  SmartSessionMode,
} from "@rhinestone/module-sdk";

import {
  type Address,
  type Chain,
  type Hex,
  createPublicClient,
  encodeFunctionData,
  erc20Abi,
  http,
  toBytes,
  toHex,
} from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import {
  createPaymasterClient,
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";
import { createSmartAccountClient } from "permissionless";
import { erc7579Actions } from "permissionless/actions/erc7579";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { toSafeSmartAccount } from "permissionless/accounts";
import { getAccountNonce } from "permissionless/actions";

const safe4337ModuleAddress = "0x7579EE8307284F293B1927136486880611F20002";
const erc7579LaunchpadAddress = "0x7579011aB74c46090561ea277Ba79D510c6C00ff";

export default async function main ({
  bundlerUrl,
  rpcUrl,
  paymasterUrl,
  chain
}: {
  bundlerUrl: string;
  rpcUrl: string;
  paymasterUrl: string;
  chain: Chain;
}) {
  const publicClient = createPublicClient({
    transport: http(rpcUrl),
    chain: chain,
  });

  const pimlicoClient = createPimlicoClient({
    transport: http(bundlerUrl),
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
  });

  const paymasterClient = createPaymasterClient({
    transport: http(paymasterUrl)
  });

  const owner = privateKeyToAccount(generatePrivateKey());

  console.log("owner:", owner);

  const ownableValidator = getOwnableValidator({
    owners: [owner.address],
    threshold: 1,
  });

  console.log(`ownableValidator: ${ownableValidator.address}`);
  console.log(`ownableValidator initData:`, ownableValidator.initData);

  const safeAccount = await toSafeSmartAccount({
    client: publicClient,
    owners: [owner],
    version: "1.4.1",
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
    safe4337ModuleAddress,
    erc7579LaunchpadAddress,
    attesters: [
      RHINESTONE_ATTESTER_ADDRESS,
    ],
    attestersThreshold: 1,
    validators: [
      {
        address: ownableValidator.address,
        context: ownableValidator.initData,
      }
    ]
  });

  console.log("safe account:", safeAccount);

  const smartAccountClient = createSmartAccountClient({
    account: safeAccount,
    chain: chain,
    bundlerTransport: http(bundlerUrl),
    paymaster: paymasterClient,
    userOperation: {
      estimateFeesPerGas: async () => {
        return (await pimlicoClient.getUserOperationGasPrice()).fast;
      },
    },
  }).extend(erc7579Actions());

  const sessionOwner = privateKeyToAccount(generatePrivateKey());

  console.log("sessionOwner:", sessionOwner);

  const session: Session = {
    sessionValidator: OWNABLE_VALIDATOR_ADDRESS,
    sessionValidatorInitData: encodeValidationData({
      threshold: 1,
      owners: [sessionOwner.address]
    }),
    salt: toHex(toBytes("0", { size: 32 })),
    userOpPolicies: [getSudoPolicy()],
    erc7739Policies: {
      allowedERC7739Content: [],
      erc1271Policies: [],
    },
    actions: [{
      // an address as the target of the session execution
      actionTarget: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238" as Address,
      // function selector to be used in the execution
      actionTargetSelector: "0x70a08231" as Hex,
      actionPolicies: [getSudoPolicy()],
    }],
    chainId: BigInt(chain.id),
    permitERC4337Paymaster: true
  };

  console.log("session:", session);

  const smartSessions = getSmartSessionsValidator({
    sessions: [session],
  });

  console.log("smart session:", smartSessions);

  const opHash = await smartAccountClient.installModule(smartSessions);

  console.log("opHash:", opHash);

  let receipt = await pimlicoClient.waitForUserOperationReceipt({
    hash: opHash,
  });

  console.log("installModule receipt:", receipt);

  const sessionDetails = {
    mode: SmartSessionMode.USE,
    permissionId: getPermissionId({ session }),
    signature: getOwnableValidatorMockSignature({ threshold: 1 })
  };

  const nonce = await getAccountNonce(publicClient, {
    address: safeAccount.address,
    entryPointAddress: entryPoint07Address,
    key: encodeValidatorNonce({
      account: getAccount({
        address: safeAccount.address,
        type: "safe",
      }),
      validator: smartSessions,
    }),
  });

  console.log("safeAcct nonce:", nonce);

  // NX: reverted here
  const userOperation = await smartAccountClient.prepareUserOperation({
    account: safeAccount,
    calls: [{
      to: session.actions[0].actionTarget,
      value: BigInt(0),
      data: encodeFunctionData({
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [safeAccount.address],
      }),
    }],
    nonce,
    signature: encodeSmartSessionSignature(sessionDetails)
  });

  const userOpHashToSign = getUserOperationHash({
    chainId: chain.id,
    entryPointAddress: entryPoint07Address,
    entryPointVersion: "0.7",
    userOperation,
  });

  console.log("userOpHash:", userOpHashToSign);

  sessionDetails.signature = await sessionOwner.signMessage({
    message: { raw: userOpHashToSign }
  });

  console.log("session detail signature:", sessionDetails.signature);

  userOperation.signature = encodeSmartSessionSignature(sessionDetails);

  console.log("userOp signature:", userOperation.signature);

  const userOpHash = await smartAccountClient.sendUserOperation(userOperation);

  console.log("userOp hash:", userOpHash);

  receipt = await pimlicoClient.waitForUserOperationReceipt({
    hash: userOpHash,
  });

  console.log("final receipt:", receipt);

  return receipt;
}
