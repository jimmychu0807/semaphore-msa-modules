"use client";

import clsx from "clsx";

import { Button } from "./Button";
import { useAppContext } from "@/contexts/AppContext";
import { Step } from "@/types";
import { Identity } from "@semaphore-protocol/identity";

export function IdentityPanel() {
  const { appState, dispatch } = useAppContext();
  const { identities, nextId, step } = appState;

  function createIdentity() {
    const identity = new Identity();
    dispatch({
      type: "insertIdentity",
      value: { key: `identity${nextId}`, identity },
    });
    dispatch({
      type: "update",
      value: { nextId: nextId + 1 },
    });

    if (step < Step.SetSmartAccount) {
      dispatch({
        type: "setStep",
        value: Step.SetSmartAccount,
      });
    }
  }

  function clearAllIdentities() {
    dispatch({ type: "clearAllIdentities" });
    dispatch({
      type: "update",
      value: { nextId: 1 },
    });
    dispatch({
      type: "setStep",
      value: Step.SetIdentity,
    });
  }

  function clearIdentity(key: string) {
    dispatch({
      type: "clearIdentity",
      value: key,
    });
  }

  const btnClassNames = clsx(
    "inline-flex items-center text-center text-sm rounded-full w-6 h-6 bg-red-200 text-red-600 font-semibold m-0 p-0"
  );

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="py-3 w-full">
        <div className="text-center my-2 font-semibold">Identity Commitments</div>
        {identities.length > 0 ? (
          <div className="py-3">
            {identities.map(({ key, identity }) => (
              <div className="flex flex-row items-center gap-2" key={key}>
                <div className="text-sm">{key}</div>
                <div className="text-sm overflow-x-scroll w-full px-3 py-1.5 my-2 bg-black/5 rounded-sm">
                  {identity.commitment.toString()}
                </div>
                <Button className={btnClassNames} buttonText="X" onClick={() => clearIdentity(key)} />
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-3">You don&apos;t have any Semaphore Identity, create one below.</div>
        )}
        <div className="flex flex-row justify-center gap-8">
          <Button buttonText="Create an Identity" onClick={createIdentity} />
          <Button buttonText="Forget all identities" onClick={clearAllIdentities} />
        </div>
      </div>
    </div>
  );
}
