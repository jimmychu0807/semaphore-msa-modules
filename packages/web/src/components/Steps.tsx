"use client";

import { type Address } from "viem";
import { useAccount } from "wagmi";

import { Button } from "./Button";

export function Steps() {
  const account = useAccount();
  const isConnected = !!account.address;

  if (!isConnected) return <ConnectWithWallet />;

  function createIdentity(address: Address) {
    console.log(address);
  }

  return (
    <section className="flex flex-col">
      <div className="flex-1">
        <h3>Identity</h3>
      </div>
      <div className="flex-1">
        <Button buttonText="Create an Identity" onClick={() => createIdentity(account.address)} />
      </div>
    </section>
  );
}

export function ConnectWithWallet() {
  return <div>Please connect with your wallet.</div>;
}
