import { type SmartAccountClient } from "permissionless";
import { type Address, type Hex, Chain, Transport } from "viem";
import { ToSafeSmartAccountReturnType } from "permissionless/accounts";
import { Erc7579Actions } from "permissionless/actions/erc7579";
import { Identity } from "@semaphore-protocol/identity";
import { type ActionDispatch } from "react";

export type AppSmartAccountClient = SmartAccountClient<Transport, Chain, ToSafeSmartAccountReturnType<"0.7">> &
  Erc7579Actions<ToSafeSmartAccountReturnType<"0.7">>;

export type Transaction = {
  to?: Address;
  value?: bigint;
  txHash: Hex;
  signatureCnt?: number;
};

export type TAppState = {
  identities: Array<{ key: string; identity: Identity }>;
  nextId: number;
  step: Step;
  status: "pending" | "ready";

  smartAccountClient?: AppSmartAccountClient;
  saltNonce?: bigint;
  commitments?: bigint[];
  acctThreshold?: number;
  executorInstalled: boolean;
  validatorInstalled: boolean;

  txs: Transaction[];
};

export type TAppAction =
  | { type: "init"; value: TAppState }
  | { type: "insertIdentity"; value: { key: string; identity: Identity } }
  | { type: "clearIdentity"; value: string }
  | { type: "clearAllIdentities" }
  | { type: "setSmartAccountClient"; value: AppSmartAccountClient }
  | { type: "clearSmartAccountClient" }
  | { type: "setStep"; value: Step }
  | { type: "installExecutor" }
  | { type: "installValidator" }
  | { type: "newTx"; value: Hex }
  | { type: "signTx"; value: Hex }
  | { type: "updateTx"; value: Transaction }
  | { type: "clearTx"; value: Hex }
  | { type: "clearTxs" }
  | {
      type: "update";
      value: {
        acctThreshold?: number;
        commitments?: bigint[];
        saltNonce?: bigint;
        nextId?: number;
      };
    };

export type TAppContext = {
  appState: TAppState;
  dispatch: ActionDispatch<[action: TAppAction]>;
};

export enum Step {
  SetIdentity = 0,
  SetSmartAccount,
  InstallModules,
  Transactions,
}
