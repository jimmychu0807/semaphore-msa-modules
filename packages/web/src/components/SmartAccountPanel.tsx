"use client";

import { type FormEvent, useState } from "react";
import {
  useAccount,
  useBalance,
  useConnect,
  useDisconnect,
  usePublicClient,
  useSwitchChain,
  useWalletClient,
} from "wagmi";
import { Field, Fieldset, Description, Label, Legend, Input } from "@headlessui/react";

import { Button } from "./Button";
import { formatEther, getSmartAccountClient } from "@/utils";
import { useAppContext } from "@/contexts/AppContext";
import { Step } from "@/types";

export function SmartAccountPanel({ requiredChainId }: { requiredChainId: number }) {
  const walletAccount = useAccount();
  const walletClient = useWalletClient();
  const { appState, dispatch } = useAppContext();
  const { smartAccountClient } = appState;

  const { data: walletBalance } = useBalance({
    address: walletAccount?.address,
    query: { refetchInterval: 4000 },
  });

  const { data: smartAcctBalance } = useBalance({
    address: smartAccountClient?.account?.address,
    query: { refetchInterval: 4000 },
  });

  const { connectors, connect } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();

  const [isCreateHandling, setCreateHandling] = useState(false);
  const publicClient = usePublicClient();

  async function createAccount(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    if (!walletClient.data) {
      console.error("No wallet account connected.");
      return;
    }

    const formData = new FormData(ev.target as HTMLFormElement);
    const saltNonce = BigInt((formData.get("saltNonce") ?? 0) as number);

    setCreateHandling(true);

    try {
      const _smartAccountClient = await getSmartAccountClient({
        publicClient,
        saltNonce,
        owners: [walletClient.data],
      });

      dispatch({ type: "setSmartAccountClient", value: _smartAccountClient });
      dispatch({ type: "setStep", value: Step.InstallModules });
    } catch (err) {
      console.error("createAccount error:", err);
    }

    setCreateHandling(false);
  }

  function forgetAccount() {
    dispatch({ type: "clearSmartAccountClient" });
    dispatch({ type: "setStep", value: Step.SetSmartAccount });
  }

  const inputClass = "mt-1 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black";

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="py-3 w-7/8">
        {walletAccount.status === "connected" || walletAccount.status === "reconnecting" ? (
          <>
            <div className="text-center my-2 font-semibold">Your Wallet Account</div>
            <div className="text-center text-sm py-1.5 my-2">
              {walletAccount.address}
              {walletBalance && ` (${formatEther(walletBalance.value)} ${walletBalance.symbol})`}
            </div>
            <div className="flex flex-row gap-x-4 justify-center">
              {walletAccount.chainId !== requiredChainId && (
                <Button buttonText="Swtich Network" onClick={() => switchChain({ chainId: requiredChainId })} />
              )}
              <Button buttonText="Disconnect" onClick={() => disconnect()} />
            </div>
          </>
        ) : (
          <>
            <div className="text-center my-2 font-semibold">Connect Wallet</div>
            <div className="flex flex-row gap-x-4 justify-center">
              {connectors.map((c) => (
                <Button key={c.uid} buttonText={c.name} onClick={() => connect({ connector: c })} />
              ))}
            </div>
          </>
        )}
      </div>

      {!!smartAccountClient ? (
        <div className="py-3 w-7/8">
          <div className="text-center my-2 font-semibold">Your Smart Account</div>
          <div className="text-center text-sm py-1.5 my-2">
            {smartAccountClient.account.address}
            {smartAcctBalance && ` (${formatEther(smartAcctBalance.value)} ${smartAcctBalance.symbol})`}
          </div>
          <div className="flex flex-row gap-x-4 justify-center">
            <Button buttonText="Forget Account" onClick={() => forgetAccount()} />
          </div>
        </div>
      ) : (
        <form className="w-7/8 flex flex-col items-center" onSubmit={createAccount}>
          <Fieldset className="space-y-6 rounded-xl p-3 w-full">
            <Legend className="text-base/4 font-semibold text-black">Claim Smart Account</Legend>
            <Field>
              <Label className="text-sm/6 font-medium text-black">Salt Nonce</Label>
              <Description className="text-xs text-black/50">
                Same owner and salt nonce will always result in the same account address
              </Description>
              <Input name="saltNonce" type="number" min="0" placeholder="0" required className={inputClass} />
            </Field>
          </Fieldset>
          <Button buttonText="Create" isSubmit={true} isLoading={isCreateHandling} onClick={() => {}} />
        </form>
      )}
    </div>
  );
}
