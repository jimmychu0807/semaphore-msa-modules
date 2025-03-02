"use client";

import { Button } from "./Button";

const TEST_IDENTITY_CMT = 5926199064674296336324214663897687094599930109695195936304576785549579890551n;

export function IdentityPanel({ identity, setIdentity }) {
  function createIdentity() {
    setIdentity(TEST_IDENTITY_CMT);
  }

  function forgetIdentity() {
    setIdentity(null);
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
          <Button buttonText="Create an Identity" onClick={() => createIdentity()} />
        </div>
      )}
    </div>
  );
}
