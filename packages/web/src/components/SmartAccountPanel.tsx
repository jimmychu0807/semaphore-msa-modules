"use client";

import { type FormEvent, useState } from "react";
import { type Address } from "viem";
import { useBalance, usePublicClient, useWalletClient } from "wagmi";
import { Field, Label, Input } from "@headlessui/react";

import { Button } from "./Button";
import { accountSaltNonce, formatEther, getSmartAccountClient } from "@/utils";
import { useAppContext } from "@/contexts/AppContext";
import { Step } from "@/types";

export function SmartAccountPanel() {
  const walletClient = useWalletClient();
  const { appState, dispatch } = useAppContext();

  const { smartAccountClient } = appState;
  const { data: balance } = useBalance({ address: smartAccountClient?.account?.address });

  const [isCreateHandling, setCreateHandling] = useState(false);
  const [isClaimHandling, setClaimHandling] = useState(false);
  const publicClient = usePublicClient();

  async function createAccount() {
    if (!walletClient.data) {
      console.error("No wallet account");
      return;
    }

    setCreateHandling(true);

    const _smartAccountClient = await getSmartAccountClient({
      publicClient,
      saltNonce: accountSaltNonce,
      owners: [walletClient.data],
    });

    dispatch({ type: "setSmartAccountClient", value: _smartAccountClient });
    dispatch({ type: "setStep", value: Step.InstallModules });

    setCreateHandling(false);
  }

  function forgetAccount() {
    dispatch({ type: "clearSmartAccountClient" });
    dispatch({ type: "setStep", value: Step.SetSmartAccount });
  }

  async function claimAccount(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!walletClient.data) {
      console.error("No wallet account");
      return;
    }

    setClaimHandling(true);

    const formData = new FormData(ev.target as HTMLFormElement);
    const address = formData.get("address") as Address;
    const commitments: bigint[] = (formData.get("commitments") as string).split(" ").map((c) => BigInt(c));

    const _smartAccountClient = await getSmartAccountClient({
      publicClient,
      address,
      saltNonce: accountSaltNonce,
      owners: [walletClient.data],
    });

    dispatch({ type: "setSmartAccountClient", value: _smartAccountClient });
    dispatch({ type: "update", value: { commitments } });
    dispatch({ type: "setStep", value: Step.InstallModules });

    setClaimHandling(false);
  }

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
          <Button buttonText="Create a Smart Account" onClick={createAccount} isLoading={isCreateHandling} />
          <div className="py-3">or</div>
          <form className="w-3/4" onSubmit={claimAccount}>
            <Field className="py-3">
              <Label className="text-sm/6 font-medium text-black block">Claim an account</Label>
              <Input
                name="address"
                className="mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black"
                required
              />
            </Field>
            <Field className="py-3">
              <Label className="text-sm/6 font-medium text-black block">Member commitments (space separated)</Label>
              <Input
                name="commitments"
                className="mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black"
                required
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
