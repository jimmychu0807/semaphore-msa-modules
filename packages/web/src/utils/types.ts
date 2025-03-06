import { type SmartAccountClient } from "permissionless";
import { Chain, Transport } from "viem";
import { ToSafeSmartAccountReturnType } from "permissionless/accounts";
import { Erc7579Actions } from "permissionless/actions/erc7579";

export type AppSmartAccountClient = SmartAccountClient<Transport, Chain, ToSafeSmartAccountReturnType<"0.7">> &
  Erc7579Actions<ToSafeSmartAccountReturnType<"0.7">>;
