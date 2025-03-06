"use client";

import { useEffect, useState } from "react";

import { Button } from "./Button";
import { useAppState, useMutateAppState, useClearAppState } from "@/hooks/useAppState";
import { Identity } from "@semaphore-protocol/identity";

export function IdentityPanel() {
  const { isPending, data: sk } = useAppState("identitySk");
  const mutateSk = useMutateAppState("identitySk");
  const clearSk = useClearAppState("identitySk");

  const [identity, setIdentity] = useState<Identity | null>();
  const mutateStep = useMutateAppState("step");

  useEffect(() => {
    if (sk) {
      setIdentity(Identity.import(sk));
    }
  }, [sk]);

  function createIdentity() {
    const newId = new Identity();
    setIdentity(newId);
    mutateSk.mutate(newId.export(), {
      onSuccess: () => mutateStep.mutate("setSmartAccount"),
    });
  }

  function forgetIdentity() {
    setIdentity(null);
    clearSk.mutate();
    mutateStep.mutate("setIdentity");
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
