"use client";

import { type FormEvent, type ChangeEvent, useState } from "react";
import { useBalance } from "wagmi";

import { Description, Field, Fieldset, Input, Label, Legend, Select } from "@headlessui/react";
import clsx from "clsx";

import { Button } from "./Button";
import { useAppContext } from "@/contexts/AppContext";
import { Step } from "@/types";
import { formatEther, getCommitmentsSorted } from "@/utils";
import { getSemaphoreExecutor, getSemaphoreValidator } from "@semaphore-msa-modules/lib";

export function InstallModulesPanel() {
  const { appState, dispatch } = useAppContext();
  const { identities, executorInstalled, validatorInstalled, smartAccountClient } = appState;

  const [installingExecutor, setInstallingExecutor] = useState<boolean>(false);
  const [installingValidator, setInstallingValidator] = useState<boolean>(false);
  const [selectedCmts, setSelectedCmts] = useState<string[]>([]);

  const { data: smartAcctBalance } = useBalance({
    address: smartAccountClient?.account?.address,
    query: { refetchInterval: 4000 },
  });

  async function installExecutorModule(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!appState.smartAccountClient) {
      console.error("smart account client is not setup");
      return;
    }

    const { smartAccountClient } = appState;

    const formData = new FormData(ev.target as HTMLFormElement);
    const commitments = selectedCmts.map((key) => identities.find((id) => id.key === key)!.identity.commitment);
    const semaphoreCommitments = getCommitmentsSorted(commitments.map((c) => BigInt(c)));
    const threshold = Number(formData.get("threshold"));

    if (threshold > semaphoreCommitments.length) {
      console.error("threshold value should be less than or equal to the number of selected members.");
      return;
    }

    setInstallingExecutor(true);

    try {
      const semaphoreExecutor = await getSemaphoreExecutor({
        threshold,
        semaphoreCommitments,
      });
      const opHash = await smartAccountClient.installModule(semaphoreExecutor);
      const receipt = await smartAccountClient.waitForUserOperationReceipt({ hash: opHash });
      console.log("receipt:", receipt);

      dispatch({ type: "installExecutor" });
      dispatch({
        type: "update",
        value: {
          acctThreshold: threshold,
          commitments: semaphoreCommitments,
        },
      });
    } catch (err) {
      console.error("installExecutorModule error:", err);
    } finally {
      setInstallingExecutor(false);
    }
  }

  async function installValidatorModule(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!appState.smartAccountClient) {
      console.error("smart account client is not setup");
      return;
    }

    const { smartAccountClient } = appState;
    setInstallingValidator(true);

    try {
      const semaphoreValidator = await getSemaphoreValidator();
      const opHash = await smartAccountClient.installModule(semaphoreValidator);
      const receipt = await smartAccountClient.waitForUserOperationReceipt({ hash: opHash });
      console.log("receipt:", receipt);

      dispatch({ type: "installValidator" });
      dispatch({ type: "setStep", value: Step.Transactions });
    } catch (err) {
      console.error("installValidatorModule error:", err);
    } finally {
      setInstallingValidator(false);
    }
  }

  function updateSelectedCmts(ev: ChangeEvent<HTMLSelectElement>) {
    const selectedOptions = Array.from(ev.target.options)
      .filter((op) => op.selected)
      .map((op) => op.value);

    setSelectedCmts(selectedOptions);
  }

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2 data-[focus]:outline-white/25"
  );

  if (!smartAccountClient) {
    return <div>Please setup a smart account first.</div>;
  }

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="text-sm py-3">
        {smartAccountClient?.account?.address}
        {smartAcctBalance && ` (${formatEther(smartAcctBalance.value)} ${smartAcctBalance.symbol})`}
      </div>
      {!executorInstalled ? (
        <form className="block w-full max-w-lg px-4" onSubmit={installExecutorModule}>
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Executor Module</Legend>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Account Members</Label>
              <Description className="text-xs text-black/50">
                Hold ctrl/cmd key to select multiple members&nbsp; (
                <span className="font-semibold">{selectedCmts.length}</span>
                &nbsp;{selectedCmts.length > 1 ? "identities" : "identity"} selected)
              </Description>
              <Select
                className="w-full rounded-md border-none bg-black/5 py-1.5 px-2 mt-2 mb-1 text-sm text-black overflow-x-scroll"
                name="commitments"
                aria-label="Member commitments"
                onChange={updateSelectedCmts}
                multiple
              >
                {" "}
                {identities.map(({ key, identity }) => (
                  <option className="py-1" key={key} value={key}>
                    {key} ({identity.commitment})
                  </option>
                ))}
              </Select>
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

      {!validatorInstalled ? (
        <form className="block w-full max-w-lg px-4" onSubmit={installValidatorModule}>
          <Fieldset className="space-y-6 rounded-xl p-6">
            <Legend className="text-base/7 font-semibold text-black">Install Validator Module</Legend>
            <div className="flex justify-center">
              <Button
                disabled={!executorInstalled}
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
