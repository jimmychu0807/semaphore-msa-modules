import { useCallback, useState, useRef, type MouseEvent, type FormEvent } from "react";
import {
  Dialog,
  DialogPanel,
  DialogTitle,
  Description,
  Fieldset,
  Field,
  Label,
  Input,
  Select,
} from "@headlessui/react";

import { type Address, type Hex, parseEther, formatEther } from "viem";
import { usePublicClient } from "wagmi";
import clsx from "clsx";

import { Group } from "@semaphore-protocol/group";
import { Identity } from "@semaphore-protocol/identity";
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
import { showToastMessage } from "@/utils";
import { useAppContext } from "@/contexts/AppContext";
import { type Transaction } from "@/types";

export function TransactionsPanel() {
  const signerSelectRef = useRef<HTMLSelectElement>(null);
  const [isOpen, setIsOpen] = useState(false);
  const [isDialogBtnLoading, setDialogBtnLoading] = useState<boolean>(false);
  const [signingTx, setSigningTx] = useState<Hex>();
  const [executingTx, setExecutingTx] = useState<Hex>();
  const { appState, dispatch } = useAppContext();
  const publicClient = usePublicClient();

  const getSelectedIdentity = useCallback(
    (selectRef: React.RefObject<HTMLSelectElement | null>): Identity | undefined => {
      const signerKey = selectRef.current?.value ?? "";
      const _entry = appState.identities.find(({ key }) => key === signerKey);
      return _entry?.identity;
    },
    [appState.identities]
  );

  const inputClassNames = clsx(
    "mt-3 block w-full rounded-lg border-none bg-black/5 py-1.5 px-3 text-sm/6 text-black",
    "focus:outline-none data-[focus]:outline-2 data-[focus]:-outline-offset-2",
    "data-[focus]:outline-white/25"
  );

  const btnClassNames = clsx(
    "inline-flex items-center gap-2 rounded-md w-16 h-9 py-1.5 px-2 text-sm/6 font-semibold",
    "justify-center text-green-800 shadow-inner focus:outline-none hover:bg-green-200",
    "border border-green-500",
    "disabled:bg-gray-100 disabled:text-gray-400 disabled:border-gray-400",
    "focus:outline-1 focus:outline-white text-sm cursor-pointer"
  );

  const { identities, acctThreshold, txs } = appState;

  async function initTx(ev: FormEvent<HTMLElement>) {
    ev.preventDefault();

    const identity = getSelectedIdentity(signerSelectRef);
    const { smartAccountClient, commitments } = appState;
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

      showToastMessage("success", { tx: receipt.receipt.transactionHash });
    } catch (err) {
      const error = err as unknown as Error;
      showToastMessage("error", { message: error.toString() });
      console.error(error.toString());
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
    const identity = getSelectedIdentity(signerSelectRef);
    const { smartAccountClient, commitments } = appState;
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

      showToastMessage("success", { tx: receipt.receipt.transactionHash });
    } catch (err) {
      const error = err as unknown as Error;
      showToastMessage("error", { message: error.toString() });
      console.error(error.toString());
    }
    setSigningTx(undefined);
  }

  async function executeTx(tx: Transaction) {
    const identity = getSelectedIdentity(signerSelectRef);
    const { smartAccountClient, commitments } = appState;
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

      showToastMessage("success", { tx: receipt.receipt.transactionHash });
    } catch (err) {
      const error = err as unknown as Error;
      showToastMessage("error", { message: error.toString() });
      console.error(error.toString());
    }
    setExecutingTx(undefined);
  }

  return (
    <>
      <div className="flex flex-col items-center gap-y-3 my-3">
        <h2 className="text-center my-2 font-semibold">Signing Member</h2>
        <Select
          className="w-full rounded-md border-none bg-black/5 py-1.5 px-2 mt-2 mb-1 text-sm text-black overflow-x-scroll"
          ref={signerSelectRef}
        >
          {identities.map(({ key, identity }) => (
            <option key={key} value={key} className="py-1">
              {key} ({identity.commitment})
            </option>
          ))}
        </Select>

        <h2 className="text-center my-2 font-semibold">Pending Transactions</h2>
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
                className={btnClassNames}
                isLoading={executingTx === tx.txHash}
                disabled={!!signingTx || (executingTx && executingTx !== tx.txHash)}
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
                <Description className="text-sm text-black/70">
                  Signing with&nbsp;
                  <span className="font-semibold">{signerSelectRef.current?.value}</span>
                </Description>
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
