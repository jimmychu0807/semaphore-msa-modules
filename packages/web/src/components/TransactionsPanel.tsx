import { useState, type MouseEvent, type FormEvent } from "react";
import { Dialog, DialogPanel, DialogTitle, Fieldset, Field, Label, Input } from "@headlessui/react";

import { type Address } from "viem";
import clsx from "clsx";

import { Button } from "./Button";
import { generateRandomHex } from "@/utils";
import { type Transaction } from "@/types";

const ACCT_THRESHOLD = 3;

export function TransactionsPanel() {
  const [isOpen, setIsOpen] = useState(false);
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

  function submitTransfer(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();
    const formData = new FormData(ev.target as HTMLFormElement);
    const recipient = formData.get("recipient") as Address;
    const amount = Number(formData.get("amount"));
    console.log(`${recipient}: ${amount}`);

    setTransactions([
      ...transactions,
      {
        recipient,
        amount,
        txHash: generateRandomHex(),
        signatureCnt: 1,
      },
    ]);

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
                signatures: {tx.signatureCnt}/{ACCT_THRESHOLD}
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
        <Button buttonText="Initiate a Tx" onClick={() => setIsOpen(true)} />
        <Button buttonText="Reset" onClick={resetTransactions} />
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
                <Button isSubmit={true} buttonText="Transfer" onClick={() => {}} />
                <Button buttonText="Cancel" onClick={cancelTransfer} />
              </div>
            </form>
          </DialogPanel>
        </div>
      </Dialog>
    </>
  );
}
