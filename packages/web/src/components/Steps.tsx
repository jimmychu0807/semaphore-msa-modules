"use client";

import { type Address } from "viem";
import { useAccount } from "wagmi";
import { useState } from "react";

import { Button } from "./Button";

const TEST_IDENTITY_CMT = 5926199064674296336324214663897687094599930109695195936304576785549579890551n;

export function Steps() {
  const account = useAccount();
  const isConnected = !!account.address;
  const [identity, setIdentity] = useState();

  if (!isConnected) {
    return <div className="self-center">Please connect with your wallet</div>;
  }

  function createIdentity() {
    setIdentity(TEST_IDENTITY_CMT);
  }

  function forgetIdentity() {
    setIdentity(null);
  }

  return (
    <section className="self-center flex flex-col items-center">
      <h3 className="py-2 font-semibold">Identity</h3>
      { !!identity
        ? <>
          <div>Your Identity</div>
          <div>{identity}</div>
          <Button buttonText="Forget this Identity" onClick={ () => forgetIdentity() }/>
          </>
        : <Button buttonText="Create an Identity" onClick={() => createIdentity()} />
      }
    </section>
  );
}
