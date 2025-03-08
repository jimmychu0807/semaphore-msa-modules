"use client";

import { Button } from "./Button";
import { useAppContext } from "@/contexts/AppContext";
import { Step } from "@/utils/types";
import { Identity } from "@semaphore-protocol/identity";

export function IdentityPanel() {
  const { appState, dispatch } = useAppContext();

  const isPending = false;
  const { identity } = appState;

  function createIdentity() {
    const newId = new Identity();
    dispatch({
      type: "setIdentity",
      value: newId,
    });
    dispatch({
      type: "setStep",
      value: Step.SetSmartAccount,
    });
  }

  function forgetIdentity() {
    dispatch({ type: "clearIdentity" });
    dispatch({
      type: "setStep",
      value: Step.SetIdentity,
    });
  }

  return (
    <div className="flex flex-col justify-center items-center">
      {isPending ? (
        <div>loading...</div>
      ) : identity ? (
        <>
          <div className="py-3 w-full">
            <div className="text-center">Your Identity Commitment</div>
            <div className="text-sm overflow-x-scroll w-full px-3 py-1.5 bg-black/5 rounded-sm">
              {identity.commitment.toString()}
            </div>
          </div>
          <Button buttonText="Forget Identity" onClick={forgetIdentity} />
        </>
      ) : (
        <div className="py-4 mx-auto">
          <Button buttonText="Create an Identity" onClick={createIdentity} />
        </div>
      )}
    </div>
  );
}
