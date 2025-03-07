"use client";

import { type FormEvent, useState, useEffect } from "react";
import { Field, Fieldset, Input, Label, Legend } from "@headlessui/react";
import { usePublicClient } from "wagmi";
import clsx from "clsx";

import { Button } from "./Button";
import { useMutateAppState } from "@/hooks/useAppState";
import { AppSmartAccountClient } from "@/utils/types";
import { getCommitmentsSorted } from "@/utils";
import { getSemaphoreExecutor, getSemaphoreValidator } from "@semaphore-msa-modules/lib";

export function InstallModulesPanel({ smartAccountClient }: { smartAccountClient: AppSmartAccountClient | undefined }) {
  const [isExecutorInstalled, setExecutorInstalled] = useState<boolean>();
  const [isValidatorInstalled, setValidatorInstalled] = useState<boolean>();

  const [installingExecutor, setInstallingExecutor] = useState<boolean>(false);
  const [installingValidator, setInstallingValidator] = useState<boolean>(false);

  const mutateStep = useMutateAppState("step");
  const publicClient = usePublicClient();

  async function installExecutorModule(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!smartAccountClient) {
      console.error("smart account client is not setup");
      return;
    }

    setInstallingExecutor(true);

    const formData = new FormData(ev.target as HTMLFormElement);
    const commitmentsStr = formData.get("commitments") as string;
    const semaphoreCommitments = getCommitmentsSorted(commitmentsStr.split(" ").map((c) => BigInt(c)));
    const threshold = Number(formData.get("threshold"));

    try {
      const semaphoreExecutor = await getSemaphoreExecutor({
        threshold,
        semaphoreCommitments,
      });

      const opHash = await smartAccountClient.installModule(semaphoreExecutor);
      const receipt = await smartAccountClient.waitForUserOperationReceipt({ hash: opHash });

      console.log("receipt:", receipt);

      setExecutorInstalled(true);
    } catch (err) {
      console.error("installExecutorModule error:", err);
    } finally {
      setInstallingExecutor(false);
    }
  }

  async function installValidatorModule(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!smartAccountClient) {
      console.error("smart account client is not setup");
      return;
    }

    setInstallingValidator(true);

    try {
      const semaphoreValidator = await getSemaphoreValidator();

      const opHash = await smartAccountClient.installModule(semaphoreValidator);
      const receipt = await smartAccountClient.waitForUserOperationReceipt({ hash: opHash });

      console.log("receipt:", receipt);

      setValidatorInstalled(true);
      mutateStep.mutate("transactions");
    } catch (err) {
      console.error("installValidatorModule error:", err);
    } finally {
      setInstallingValidator(false);
    }
  }

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2 data-[focus]:outline-white/25"
  );

  useEffect(() => {
    let isMounted = true;

    const checkIsModulesInstalled = async () => {
      if (!smartAccountClient || !publicClient || !smartAccountClient?.account) return;

      // Check that the smart account has been initialized
      const address = smartAccountClient.account.address;
      const isAcctInited = await publicClient.getCode({ address });
      if (!isAcctInited) return;

      const eInstalled = await smartAccountClient.isModuleInstalled(getSemaphoreExecutor());
      const vInstalled = await smartAccountClient.isModuleInstalled(getSemaphoreValidator());

      if (isMounted) {
        setExecutorInstalled(eInstalled);
        setValidatorInstalled(vInstalled);
      }
    };

    checkIsModulesInstalled();

    return () => {
      isMounted = false;
    };
  }, [publicClient, smartAccountClient]);

  if (!smartAccountClient) {
    return <div>Please setup a smart account first.</div>;
  }

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="text-sm py-3">Smart Account: {smartAccountClient?.account?.address}</div>
      {!isExecutorInstalled ? (
        <form className="block w-full max-w-lg px-4" onSubmit={installExecutorModule}>
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Executor Module</Legend>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Member Commitments (space separated)</Label>
              <Input type="text" name="commitments" className={inputClassNames} />
            </Field>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Proof Threshold</Label>
              <Input type="number" name="threshold" min="1" className={inputClassNames} />
            </Field>
            <div className="flex justify-center">
              <Button
                buttonText="Install Executor Module"
                isLoading={installingExecutor}
                isSubmit={true}
                onClick={() => {}}
              />
            </div>
          </Fieldset>
        </form>
      ) : (
        <div className="text-sm my-3">Semaphore Executor Module has been installed in your smart account.</div>
      )}

      {!isValidatorInstalled ? (
        <form className="block w-full max-w-lg px-4" onSubmit={installValidatorModule}>
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Validator Module</Legend>
            <div className="flex justify-center">
              <Button
                disabled={!isExecutorInstalled}
                buttonText="Install Validator Module"
                isLoading={installingValidator}
                isSubmit={true}
                onClick={() => {}}
              />
            </div>
          </Fieldset>
        </form>
      ) : (
        <div className="text-sm my-3">Semaphore Validator Module has been installed in your smart account.</div>
      )}
    </div>
  );
}
