"use client";

import { Button } from "./Button";
import { useAppState, useMutateAppState, useClearAppState } from "@/hooks/useAppState";

const TEST_IDENTITY_CMT = 5926199064674296336324214663897687094599930109695195936304576785549579890551n;

export function IdentityPanel() {
  const { data: identity } = useAppState("identity");
  const mutateId = useMutateAppState("identity");
  const clearId = useClearAppState("identity");

  const mutateStep = useMutateAppState("step");

  function createIdentity(cmt: bigint) {
    mutateId.mutate(cmt.toString(), {
      onSuccess: () => mutateStep.mutate("setSmartAccount"),
    });
  }

  function forgetIdentity() {
    clearId.mutate(null, {
      onSuccess: () => mutateStep.mutate("setIdentity"),
    });
  }

  return (
    <div className="flex flex-col justify-center items-center">
      {!!identity ? (
        <>
          <div className="py-3">
            <div className="text-center">Your Identity</div>
            <div className="text-sm">{identity}</div>
          </div>
          <Button buttonText="Forget this Identity" onClick={() => forgetIdentity()} />
        </>
      ) : (
        <div className="py-4 mx-auto">
          <Button buttonText="Create an Identity" onClick={() => createIdentity(TEST_IDENTITY_CMT)} />
        </div>
      )}
    </div>
  );
}
