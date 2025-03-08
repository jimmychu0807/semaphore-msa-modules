import { type SmartAccountClient } from "permissionless";
import { type Address, type Hex, Chain, Transport } from "viem";
import { ToSafeSmartAccountReturnType } from "permissionless/accounts";
import { Erc7579Actions } from "permissionless/actions/erc7579";
import { Identity } from "@semaphore-protocol/identity";
import { type ActionDispatch } from "react";

export type AppSmartAccountClient = SmartAccountClient<Transport, Chain, ToSafeSmartAccountReturnType<"0.7">> &
  Erc7579Actions<ToSafeSmartAccountReturnType<"0.7">>;

export type TAppState = {
  identity?: Identity;
  smartAccountClient?: AppSmartAccountClient;
  step: Step;
  executorInstalled: boolean;
  validatorInstalled: boolean;
  status: "pending" | "ready";
};

export type TAppAction =
  | { type: "init"; value: TAppState }
  | { type: "setIdentity"; value: Identity }
  | { type: "clearIdentity" }
  | { type: "setSmartAccountClient"; value: AppSmartAccountClient }
  | { type: "clearSmartAccountClient" }
  | { type: "setStep"; value: Step }
  | { type: "installExecutor" }
  | { type: "installValidator" };

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

export type Transaction = {
  recipient: Address;
  amount: number;
  txHash: Hex;
  signatureCnt: number;
};
