"use client";

import { useBalance } from "wagmi";
import { Field, Label, Input } from "@headlessui/react";

import { Button } from "./Button";
import { formatEther } from "@/utils/clients";

const TEST_SMART_ACCOUNT = "0xEA638A0eDB7878269bef7CAAE61050b3A14AF311";

export function SmartAccountPanel({ smartAccount, setSmartAccount }) {
  const { data: balance } = useBalance({ address: smartAccount });

  function createAccount() {
    setSmartAccount(TEST_SMART_ACCOUNT);
  }

  function forgetAccount() {
    setSmartAccount(null);
  }

  function claimAccount() {
    setSmartAccount(TEST_SMART_ACCOUNT);
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
          <Button buttonText="Create a Smart Account" onClick={() => createAccount()} />
          <div className="py-3">or</div>
          <form>
            <Field className="py-3">
              <Label className="text-sm/6 font-medium text-black block text-center">Claim an account</Label>
              <Input className="mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black" />
            </Field>
            <Button buttonText="Claim" onClick={() => claimAccount()} />
          </form>
        </>
      )}
    </div>
  );
}
