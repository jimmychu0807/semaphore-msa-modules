"use client";

import { type MouseEvent } from "react";
import { Field, Fieldset, Input, Label, Legend } from "@headlessui/react";
import clsx from "clsx";

import { Button } from "./Button";
import { useAppState, useMutateAppState } from "@/hooks/useAppState";
import { AppSmartAccountClient } from "@/utils/types";

export function InstallModulesPanel({ smartAccountClient }: { smartAccountClient: AppSmartAccountClient | undefined }) {
  const { data: smartAccount } = useAppState("smartAccount");
  const { data: isExecutorInstalled } = useAppState("isExecutorInstalled");
  const setExecutor = useMutateAppState("isExecutorInstalled");

  const { data: isValidatorInstalled } = useAppState("isValidatorInstalled");
  const setValidator = useMutateAppState("isValidatorInstalled");

  const mutateStep = useMutateAppState("step");

  function installExecutorModule(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    setExecutor.mutate(true);
  }

  function installValidatorModule(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    setValidator.mutate(true, {
      onSuccess: () => mutateStep.mutate("transactions"),
    });
  }

  function resetModules() {
    setExecutor.mutate(false);
    setValidator.mutate(false);
    mutateStep.mutate("installModules");
  }

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2 data-[focus]:outline-white/25"
  );

  console.log("smart acct client:", smartAccountClient);

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="text-sm py-3">Smart Account: {smartAccount}</div>
      {!isExecutorInstalled ? (
        <form className="block w-full max-w-lg px-4">
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Executor Module</Legend>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Member Commitments (space separated)</Label>
              <Input type="text" className={inputClassNames} />
            </Field>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Proof Threshold</Label>
              <Input type="number" className={inputClassNames} />
            </Field>
            <div className="flex justify-center">
              <Button buttonText="Install Executor Module" onClick={installExecutorModule} />
            </div>
          </Fieldset>
        </form>
      ) : (
        <div className="text-sm">Semaphore Executor Module has been installed in your smart account.</div>
      )}

      {!isValidatorInstalled ? (
        <form className="block w-full max-w-lg px-4">
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Validator Module</Legend>
            <div className="flex justify-center">
              <Button
                disabled={!isExecutorInstalled}
                buttonText="Install Validator Module"
                onClick={installValidatorModule}
              />
            </div>
          </Fieldset>
        </form>
      ) : (
        <div className="text-sm">Semaphore Validator Module has been installed in your smart account.</div>
      )}

      {isValidatorInstalled && isValidatorInstalled && (
        <div className="py-4">
          <Button buttonText="Reset Modules" onClick={() => resetModules()} />
        </div>
      )}
    </div>
  );
}
