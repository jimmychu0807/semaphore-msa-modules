import { useState, type MouseEvent, type FormEvent } from "react";
import { Dialog, DialogPanel, DialogTitle, Fieldset, Field, Label, Input } from "@headlessui/react";

import { type Address, parseEther } from "viem";
import { usePublicClient } from "wagmi";
import clsx from "clsx";

import { Group } from "@semaphore-protocol/group";
import { generateProof } from "@semaphore-protocol/proof";

import {
  type SemaphoreProofFix,
  getAcctSeqNum,
  getTxHash,
  getInitTxAction,
  sendSemaphoreTransaction,
} from "@semaphore-msa-modules/lib";

import { Button } from "./Button";
import { generateRandomHex } from "@/utils";
import { useAppContext } from "@/contexts/AppContext";
import { type Transaction } from "@/types";

export function TransactionsPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const [isDialogBtnLoading, setDialogBtnLoading] = useState<boolean>(false);
  const { appState } = useAppContext();
  const publicClient = usePublicClient();
  const [transactions, setTransactions] = useState<Array<Transaction>>([]);

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2",
    "data-[focus]:outline-white/25"
  );

  const btnClassNames = clsx(
    "inline-flex items-center gap-2 rounded-md bg-green-200 py-1.5 px-2 text-sm/6 font-semibold",
    "text-green-800 shadow-inner focus:outline-none data-[hover]:bg-green-200",
    "data-[open]:bg-green-200 data-[focus]:outline-1 data-[focus]:outline-white text-sm"
  );

  const { acctThreshold } = appState;

  async function submitTransfer(ev: FormEvent<HTMLElement>) {
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
      console.log("proof:", smProof);

      const action = getInitTxAction(recipient, value, "0x", smProof, false);
      const receipt = await sendSemaphoreTransaction({
        signer: identity,
        account,
        action,
        publicClient,
        bundlerClient: smartAccountClient,
      });

      console.log("receipt:", receipt);
    } catch (err) {
      console.error("submitTransfer error:", err);
    }

    setDialogBtnLoading(false);
    setIsOpen(false);
  }

  function cancelTransfer(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    setIsOpen(false);
  }

  function resetTransactions(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    setTransactions([]);
  }

  function signTx(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    console.log("signTx");
  }

  function executeTx(ev: MouseEvent<HTMLElement>) {
    ev.preventDefault();
    console.log("executeTx");
  }

  return (
    <>
      <div className="flex flex-col items-center gap-y-3 my-3">
        <h2>Pending Transactions</h2>
        {transactions.map((tx: Transaction) => (
          <div key={tx.txHash} className="flex flex-row items-center w-full">
            <div className="w-3/4 text-xs">
              <div>tx hash: {tx.txHash}</div>
              <div>recipient: {tx.recipient}</div>
              <div>value: {tx.amount} ETH</div>
              <div>
                signatures: {tx.signatureCnt}/{acctThreshold}
              </div>
            </div>
            <div className="w-1/4 flex flex-row justify-evenly">
              <button className={btnClassNames} onClick={signTx}>
                Sign
              </button>
              <button className={btnClassNames} onClick={executeTx}>
                Execute
              </button>
            </div>
          </div>
        ))}
      </div>
      <div className="flex flex-row justify-center gap-x-4">
        <Button buttonText="Initiate Tx" onClick={() => setIsOpen(true)} />
        <Button buttonText="Reset Txs" onClick={resetTransactions} />
      </div>

      <Dialog open={isOpen} onClose={() => setIsOpen(false)} className="relative z-50">
        <div className="fixed inset-0 flex w-screen items-center justify-center p-4">
          <DialogPanel className="max-w-lg space-y-4 border bg-white p-12">
            <DialogTitle className="font-bold">Transfer Balance</DialogTitle>
            <form className="block w-full max-w-lg px-4" onSubmit={submitTransfer}>
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
                <Button buttonText="Cancel" disabled={isDialogBtnLoading} onClick={cancelTransfer} />
              </div>
            </form>
          </DialogPanel>
        </div>
      </Dialog>
    </>
  );
}
