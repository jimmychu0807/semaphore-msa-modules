"use client";

import { type ReactNode, createContext, useContext, useReducer, useEffect, useState } from "react";
import { type Address, type PublicClient, type WalletClient } from "viem";
import { usePublicClient, useWalletClient } from "wagmi";

import { accountSaltNonce, getSmartAccountClient } from "@/utils";
import { type TAppContext, type TAppState, type TAppAction, Step } from "@/types";
import { Identity } from "@semaphore-protocol/identity";
import { getSemaphoreExecutor, getSemaphoreValidator, getAcctThreshold } from "@semaphore-msa-modules/lib";

const unInitAppState: TAppState = {
  step: Step.SetIdentity,
  executorInstalled: false,
  validatorInstalled: false,
  status: "pending",
};

export const AppContext = createContext<TAppContext>({
  appState: unInitAppState,
  dispatch: () => ({}),
});

// Restoring the appstate from localstorage
async function initAppState(publicClient: PublicClient, walletClient: WalletClient): Promise<TAppState> {
  const appState: TAppState = { ...unInitAppState, status: "ready" };

  const identitySk = window.localStorage.getItem("identitySk");
  if (identitySk) {
    appState.identity = Identity.import(identitySk);
  }

  const step = window.localStorage.getItem("step");
  if (step !== undefined) {
    // step can be 0
    appState.step = Number(step) as Step;
  }

  const address = window.localStorage.getItem("smartAccountAddr") as Address;
  if (address) {
    // Restore the smart account client
    try {
      const smartAccountClient = await getSmartAccountClient({
        publicClient,
        saltNonce: accountSaltNonce,
        owners: [walletClient],
        address,
      });
      appState.smartAccountClient = smartAccountClient;

      // Check if the two modules are installed
      const isAcctInited = await publicClient.getCode({ address });
      if (isAcctInited) {
        const sme = getSemaphoreExecutor();
        const smv = getSemaphoreValidator();
        if (await smartAccountClient.isModuleInstalled(sme)) appState.executorInstalled = true;
        if (await smartAccountClient.isModuleInstalled(smv)) appState.validatorInstalled = true;
        if (appState.executorInstalled) {
          appState.acctThreshold =
            Number(await getAcctThreshold({ account: smartAccountClient.account, client: publicClient }));
        }
      }
    } catch (err) {
      console.error("Restoring smart account client error:", err);
    }
  }

  return appState;
}

function appStateReducer(appState: TAppState, action: TAppAction): TAppState {
  const { type } = action;

  switch (type) {
    case "init": {
      return action.value;
    }
    case "setIdentity": {
      return { ...appState, identity: action.value };
    }
    case "clearIdentity": {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { identity, ...newState } = appState;
      return newState;
    }
    case "setStep": {
      return { ...appState, step: action.value };
    }
    case "setSmartAccountClient": {
      return { ...appState, smartAccountClient: action.value };
    }
    case "clearSmartAccountClient": {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { smartAccountClient, ...newState } = appState;
      return newState;
    }
    case "installExecutor": {
      return { ...appState, executorInstalled: true };
    }
    case "installValidator": {
      return { ...appState, validatorInstalled: true };
    }
    default: {
      throw new Error(`Unknown action: ${action}`);
    }
  }
}

export function AppStateProvider({ children }: { children: ReactNode }) {
  const [appState, dispatch] = useReducer(appStateReducer, unInitAppState);
  const [isInit, setInit] = useState(false);
  const walletClient = useWalletClient();
  const publicClient = usePublicClient();

  useEffect(() => {
    let isMounted = true;
    const _initAppState = async () => {
      if (!window || !setInit || !publicClient || !walletClient.data) return;
      if (isInit) return;

      dispatch({ type: "init", value: await initAppState(publicClient, walletClient.data) });

      if (isMounted) {
        setInit(true);
      }
    };

    _initAppState();
    return () => {
      isMounted = false;
    };
  }, [isInit, setInit, publicClient, walletClient.data]);

  // Saving the appState in localstorage
  useEffect(() => {
    if (appState.status !== "ready") return;

    // identity. We only save the private key
    if (appState.identity === undefined) {
      localStorage.removeItem("identitySk");
    } else {
      localStorage.setItem("identitySk", appState.identity.export());
    }

    // step
    if (appState.step === undefined) {
      localStorage.removeItem("step");
    } else {
      localStorage.setItem("step", appState.step.toString());
    }

    //smartAccountClient
    if (appState.smartAccountClient === undefined) {
      localStorage.removeItem("smartAccountAddr");
    } else {
      localStorage.setItem("smartAccountAddr", appState.smartAccountClient.account.address);
    }
  }, [appState]);

  return <AppContext.Provider value={{ appState, dispatch }}>{children}</AppContext.Provider>;
}

export function useAppContext() {
  return useContext(AppContext);
}
