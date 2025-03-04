"use client";

import { type Address } from "viem";
import { useBalance } from "wagmi";
import { Field, Label, Input } from "@headlessui/react";

import { Button } from "./Button";
import { formatEther } from "@/utils/clients";
import { useAppState, useMutateAppState } from "@/hooks/useAppState";

const TEST_SMART_ACCOUNT = "0xEA638A0eDB7878269bef7CAAE61050b3A14AF311";

export function SmartAccountPanel() {
  const { data: smartAccount } = useAppState("smartAccount");
  const mutateAccount = useMutateAppState("smartAccount");
  const clearAccount = useMutateAppState("smartAccount");

  const mutateStep = useMutateAppState("step");
  const { data: balance } = useBalance({ address: smartAccount });

  function createAccount(addr: Address) {
    mutateAccount.mutate(addr, {
      onSuccess: () => mutateStep.mutate("installModules"),
    });
  }

  function forgetAccount() {
    clearAccount.mutate(null, {
      onSuccess: () => mutateStep.mutate("setSmartAccount"),
    });
  }

  function claimAccount(addr: Address, ev) {
    ev.preventDefault();

    mutateAccount.mutate(addr, {
      onSuccess: () => mutateStep.mutate("installModules"),
    });
  }

  return (
    <div className="flex flex-col justify-center items-center">
      {!!smartAccount ? (
        <>
          <div className="py-3">
            <div className="text-center">Your Smart Account</div>
            <div className="text-sm">
              {smartAccount}
              {balance && ` (${formatEther(balance.value)} ${balance.symbol})`}
            </div>
            <div className="text-sm">owner: {`owner`}</div>
          </div>
          <Button buttonText="Forget this Account" onClick={() => forgetAccount()} />
        </>
      ) : (
        <>
          <Button buttonText="Create a Smart Account" onClick={() => createAccount(TEST_SMART_ACCOUNT)} />
          <div className="py-3">or</div>
          <form>
            <Field className="py-3">
              <Label className="text-sm/6 font-medium text-black block text-center">Claim an account</Label>
              <Input className="mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black" />
            </Field>
            <div className="flex justify-center">
              <Button buttonText="Claim" onClick={(ev) => claimAccount(TEST_SMART_ACCOUNT, ev)} />
            </div>
          </form>
        </>
      )}
    </div>
  );
}
