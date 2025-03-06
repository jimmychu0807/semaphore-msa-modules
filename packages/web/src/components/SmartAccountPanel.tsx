"use client";

import { type FormEvent, type Dispatch, type SetStateAction, useState, useEffect } from "react";
import { type Address, type Account, type PublicClient, http } from "viem";
import { useAccount, useBalance, usePublicClient } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { Field, Label, Input } from "@headlessui/react";
import { createSmartAccountClient } from "permissionless";
import { toSafeSmartAccount } from "permissionless/accounts";
import { erc7579Actions } from "permissionless/actions/erc7579";
import { entryPoint07Address } from "viem/account-abstraction";
import {
  RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
  MOCK_ATTESTER_ADDRESS, // Mock Attester - do not use in production
} from "@rhinestone/module-sdk";

import { Button } from "./Button";
import { accountSaltNonce, formatEther, pimlicoClient, paymasterClient, bundlerUrl } from "@/utils/clients";
import { useAppState, useMutateAppState, useClearAppState } from "@/hooks/useAppState";
import { type AppSmartAccountClient } from "@/utils/types";

async function getSmartAccountClient({
  publicClient,
  saltNonce,
  owners,
  address,
}: {
  publicClient: PublicClient | undefined;
  saltNonce?: bigint;
  owners?: Array<Account>;
  address?: Address;
}): Promise<AppSmartAccountClient> {
  if (!publicClient) throw new Error("publicClient is falsy");
  if (!address && !saltNonce && !owners) throw new Error("not enough data to get a safe account");

  const safeAccount = await toSafeSmartAccount({
    client: publicClient,
    saltNonce,
    owners: owners || [],
    address,
    version: "1.4.1",
    entryPoint: {
      address: entryPoint07Address,
      version: "0.7",
    },
    safe4337ModuleAddress: "0x7579EE8307284F293B1927136486880611F20002",
    erc7579LaunchpadAddress: "0x7579011aB74c46090561ea277Ba79D510c6C00ff",
    attesters: [
      RHINESTONE_ATTESTER_ADDRESS, // Rhinestone Attester
      MOCK_ATTESTER_ADDRESS,
    ],
    attestersThreshold: 1,
  });

  const smartAccountClient = createSmartAccountClient({
    account: safeAccount,
    chain: baseSepolia,
    bundlerTransport: http(bundlerUrl),
    paymaster: paymasterClient,
    userOperation: {
      estimateFeesPerGas: async () => (await pimlicoClient.getUserOperationGasPrice()).fast,
    },
  }).extend(erc7579Actions());

  return smartAccountClient as unknown as AppSmartAccountClient;
}

export function SmartAccountPanel({
  smartAccountClient,
  setSmartAccountClient,
}: {
  smartAccountClient: AppSmartAccountClient | undefined;
  setSmartAccountClient: Dispatch<SetStateAction<AppSmartAccountClient | undefined>>;
}) {
  const ownerAcct = useAccount();
  const { data: smartAccountAddr } = useAppState("smartAccountAddr");
  const mutateAccountAddr = useMutateAppState("smartAccountAddr");
  const clearAccountAddr = useClearAppState("smartAccountAddr");

  const mutateStep = useMutateAppState("step");
  const { data: balance } = useBalance({ address: smartAccountClient?.account?.address });

  const [createBtnLoading, setCreateBtnLoading] = useState(false);
  const [isClaimHandling, setClaimHandling] = useState(false);
  const publicClient = usePublicClient();

  async function createAccount() {
    setCreateBtnLoading(true);

    const _smartAccountClient = await getSmartAccountClient({
      publicClient,
      saltNonce: accountSaltNonce,
      owners: [ownerAcct as unknown as Account],
    });

    setSmartAccountClient(_smartAccountClient);

    setCreateBtnLoading(false);
    mutateAccountAddr.mutate(_smartAccountClient.account.address);
    mutateStep.mutate("installModules");
  }

  function forgetAccount() {
    setSmartAccountClient(undefined);
    clearAccountAddr.mutate();

    mutateStep.mutate("setSmartAccount");
  }

  async function claimAccount(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    setClaimHandling(true);

    const formData = new FormData(ev.target as HTMLFormElement);
    const acctAddress = formData.get("acct-address") as Address;

    const _smartAccountClient = await getSmartAccountClient({
      publicClient,
      address: acctAddress,
    });
    setSmartAccountClient(_smartAccountClient);

    setClaimHandling(false);
    mutateAccountAddr.mutate(_smartAccountClient.account.address);
    mutateStep.mutate("installModules");
  }

  useEffect(() => {
    let isMounted = true;

    const toGetSmartAccountClient = async () => {
      if (smartAccountAddr) {
        const _smartAccountClient = await getSmartAccountClient({
          publicClient,
          address: smartAccountAddr,
        });

        if (isMounted) {
          setSmartAccountClient(_smartAccountClient);
        }
      }
    };

    toGetSmartAccountClient();

    return () => {
      isMounted = false;
    };
  }, [smartAccountAddr, setSmartAccountClient, publicClient]);

  return (
    <div className="flex flex-col justify-center items-center">
      {!!smartAccountClient ? (
        <>
          <div className="py-3">
            <div className="text-center">Your Smart Account</div>
            <div className="text-sm">
              {smartAccountClient.account.address}
              {balance && ` (${formatEther(balance.value)} ${balance.symbol})`}
            </div>
          </div>
          <Button buttonText="Forget Account" onClick={() => forgetAccount()} />
        </>
      ) : (
        <>
          <Button buttonText="Create a Smart Account" onClick={createAccount} isLoading={createBtnLoading} />
          <div className="py-3">or</div>
          <form className="w-2/3" onSubmit={claimAccount}>
            <Field className="py-3">
              <Label className="text-sm/6 font-medium text-black block">Claim an account</Label>
              <Input
                name="acct-address"
                className="mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black"
              />
            </Field>
            <div className="flex justify-center">
              <Button buttonText="Claim" isSubmit={true} isLoading={isClaimHandling} onClick={() => {}} />
            </div>
          </form>
        </>
      )}
    </div>
  );
}
