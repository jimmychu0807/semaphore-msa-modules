import { useState, type MouseEvent, type FormEvent } from "react";
import { Dialog, DialogPanel, DialogTitle, Fieldset, Field, Label, Input } from "@headlessui/react";

import { type Address, type Hex, parseEther, formatEther } from "viem";
import { usePublicClient } from "wagmi";
import clsx from "clsx";

import { Group } from "@semaphore-protocol/group";
import { generateProof } from "@semaphore-protocol/proof";

import {
  type SemaphoreProofFix,
  getAcctSeqNum,
  getTxHash,
  getInitTxAction,
  getSignTxAction,
  getExecuteTxAction,
  sendSemaphoreTransaction,
} from "@semaphore-msa-modules/lib";

import { Button } from "./Button";
import { useAppContext } from "@/contexts/AppContext";
import { type Transaction } from "@/types";

export function TransactionsPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const [isDialogBtnLoading, setDialogBtnLoading] = useState<boolean>(false);
  const [signingTx, setSigningTx] = useState<Hex>();
  const [executingTx, setExecutingTx] = useState<Hex>();
  const { appState, dispatch } = useAppContext();
  const publicClient = usePublicClient();

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2",
    "data-[focus]:outline-white/25"
  );

  const btnClassNames = clsx(
    "inline-flex items-center gap-2 rounded-md w-18 h-9 bg-green-200 py-1.5 px-2 text-sm/6 font-semibold",
    "justify-center text-green-800 shadow-inner focus:outline-none hover:bg-green-300",
    "disabled:bg-gray-300 disabled:text-black",
    "focus:outline-1 focus:outline-white text-sm"
  );

  const { acctThreshold, txs } = appState;

  async function initTx(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();

    const { smartAccountClient, identity, commitments } = appState;
    if (!smartAccountClient || !publicClient || !identity || !commitments) {
      console.error("[smartAccountClient, publicClient, identity, commitment] at least one values are not set.");
      return;
    }

    setDialogBtnLoading(true);
    const { account } = smartAccountClient;

    const formData = new FormData(ev.target as HTMLFormElement);
    const recipient = formData.get("recipient") as Address;
    const amount = (formData.get("amount") || "") as string;

    try {
      // Composse the initTxAction
      const seqNum = await getAcctSeqNum({ account, client: publicClient });
      const value = parseEther(amount);
      const txHash = getTxHash(seqNum, recipient, value, "0x");
      const smGroup = new Group(commitments);
      const smProof = (await generateProof(identity, smGroup, "approve", txHash)) as unknown as SemaphoreProofFix;

      const action = getInitTxAction(recipient, value, "0x", smProof, false);
      const receipt = await sendSemaphoreTransaction({
        signer: identity,
        account,
        action,
        publicClient,
        bundlerClient: smartAccountClient,
      });
      console.log("initTx receipt:", receipt);
    } catch (err) {
      console.error("initTx error:", err);
    }
    setDialogBtnLoading(false);
    setIsOpen(false);
  }

  function cancelInitTx(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    setIsOpen(false);
  }

  function resetTxs(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    dispatch({ type: "clearTxs" });
  }

  async function signTx(tx: Transaction) {
    const { smartAccountClient, identity, commitments } = appState;
    if (!smartAccountClient || !publicClient || !identity || !commitments) {
      console.error("[smartAccountClient, publicClient, identity, commitment] at least one values are not set.");
      return;
    }

    try {
      const { txHash } = tx;
      setSigningTx(txHash);
      const smGroup = new Group(commitments);
      const smProof = (await generateProof(identity, smGroup, "approve", txHash)) as unknown as SemaphoreProofFix;

      const action = getSignTxAction(txHash, smProof, false);
      const receipt = await sendSemaphoreTransaction({
        signer: identity,
        account: smartAccountClient.account,
        action,
        publicClient,
        bundlerClient: smartAccountClient,
      });
      console.log("signTx receipt:", receipt);
    } catch (err) {
      console.error("signTx error:", err);
    }
    setSigningTx(undefined);
  }

  async function executeTx(tx: Transaction) {
    const { smartAccountClient, identity, commitments } = appState;
    if (!smartAccountClient || !publicClient || !identity || !commitments) {
      console.error("[smartAccountClient, publicClient, identity, commitment] at least one values are not set.");
      return;
    }

    try {
      const { txHash } = tx;
      setExecutingTx(txHash);

      const action = getExecuteTxAction(txHash);
      const receipt = await sendSemaphoreTransaction({
        signer: identity,
        account: smartAccountClient.account,
        action,
        publicClient,
        bundlerClient: smartAccountClient,
      });
      console.log("executeTx receipt:", receipt);
    } catch (err) {
      console.error("executeTx error:", err);
    }
    setExecutingTx(undefined);
  }

  return (
    <>
      <div className="flex flex-col items-center gap-y-3 my-3">
        <h2>Pending Transactions</h2>
        {txs.map((tx: Transaction) => (
          <div key={tx.txHash} className="flex flex-row items-center w-full">
            <div className="w-3/4 text-xs overflow-y-scroll">
              <div>
                tx hash: <span className="font-semibold">{tx.txHash}</span>
              </div>
              <div>
                to: <span className="font-semibold">{tx?.to}</span>
              </div>
              <div>
                value: <span className="font-semibold">{formatEther(tx?.value ?? BigInt(0))}</span> ETH
              </div>
              <div>
                proofs: {tx.signatureCnt ?? 0} / {acctThreshold}
              </div>
            </div>
            <div className="w-1/4 flex flex-col items-center md:flex-row justify-evenly gap-2">
              <Button
                buttonText="Sign"
                className={btnClassNames}
                isLoading={signingTx === tx.txHash}
                disabled={!!executingTx || (signingTx && signingTx !== tx.txHash)}
                onClick={() => signTx(tx)}
              />
              <Button
                buttonText="Execute"
                isLoading={executingTx === tx.txHash}
                disabled={!!signingTx || (executingTx && executingTx !== tx.txHash)}
                className={btnClassNames}
                onClick={() => executeTx(tx)}
              />
            </div>
          </div>
        ))}
      </div>
      <div className="flex flex-row justify-center gap-x-4">
        <Button buttonText="Initiate Tx" onClick={() => setIsOpen(true)} />
        <Button buttonText="Reset Txs" onClick={resetTxs} />
      </div>

      <Dialog open={isOpen} onClose={() => setIsOpen(false)} className="relative z-50">
        <div className="fixed inset-0 flex w-screen items-center justify-center p-4">
          <DialogPanel className="max-w-lg space-y-4 border bg-white p-12">
            <DialogTitle className="font-bold">Transfer Balance</DialogTitle>
            <form className="block w-full max-w-lg px-4" onSubmit={initTx}>
              <Fieldset className="space-y-6 rounded-xl p-6">
                <Field>
                  <Label className="text-sm/6 font-medium text-black">Recipient</Label>
                  <Input className={inputClassNames} name="recipient" />
                </Field>
                <Field>
                  <Label className="text-sm/6 font-medium text-black">Amount (in ETH)</Label>
                  <Input className={inputClassNames} name="amount" type="number" step="0.001" />
                </Field>
              </Fieldset>
              <div className="flex gap-4">
                <Button isSubmit={true} buttonText="Transfer" isLoading={isDialogBtnLoading} onClick={() => {}} />
                <Button buttonText="Cancel" disabled={isDialogBtnLoading} onClick={cancelInitTx} />
              </div>
            </form>
          </DialogPanel>
        </div>
      </Dialog>
    </>
  );
}
