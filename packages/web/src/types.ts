import { type SmartAccountClient } from "permissionless";
import { Chain, Transport } from "viem";
import { ToSafeSmartAccountReturnType } from "permissionless/accounts";
import { Erc7579Actions } from "permissionless/actions/erc7579";
import { Identity } from "@semaphore-protocol/identity";
import { type ActionDispatch } from "react";

export type AppSmartAccountClient = SmartAccountClient<Transport, Chain, ToSafeSmartAccountReturnType<"0.7">> &
  Erc7579Actions<ToSafeSmartAccountReturnType<"0.7">>;

export type TAppState = {
  identity?: Identity;
  step?: Step;
  smartAccountClient?: AppSmartAccountClient;
  status: "pending" | "ready";
};

export type TAppAction =
  | { type: "init"; value: TAppState }
  | { type: "setIdentity"; value: Identity }
  | { type: "clearIdentity" }
  | { type: "setSmartAccountClient"; value: AppSmartAccountClient }
  | { type: "clearSmartAccountClient" }
  | { type: "setStep"; value: Step };

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
