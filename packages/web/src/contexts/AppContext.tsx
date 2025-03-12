"use client";

import { type ReactNode, createContext, useContext, useReducer, useEffect, useState } from "react";
import { type Address, type PublicClient, type WalletClient } from "viem";
import { usePublicClient, useWalletClient, useWatchContractEvent } from "wagmi";

import { accountSaltNonce, getSmartAccountClient } from "@/utils";
import { type TAppContext, type TAppState, type TAppAction, Step } from "@/types";
import { Identity } from "@semaphore-protocol/identity";
import {
  SEMAPHORE_EXECUTOR_ADDRESS,
  getSemaphoreExecutor,
  getSemaphoreValidator,
  getAcctThreshold,
  getExtCallCount,
} from "@semaphore-msa-modules/lib";
import { semaphoreExecutorABI } from "@semaphore-msa-modules/lib/abi";

const unInitAppState: TAppState = {
  step: Step.SetIdentity,
  executorInstalled: false,
  validatorInstalled: false,
  txs: [],
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
    } catch (err) {
      console.error("Restoring smart account client error:", err);
    }
  }

  const commitments = window.localStorage.getItem("commitments");
  if (commitments) {
    appState.commitments = JSON.parse(commitments).map((c: string) => BigInt(c));
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
    // There are a few other state need to be cleared
    case "clearSmartAccountClient": {
      // Need to remove all smart account related properties:
      //   smartAccountClient, commitments, acctThreshold
      //   validatorInstalled, executorInstalled, txs
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { smartAccountClient, commitments, acctThreshold, ...newState } = appState;
      return { ...newState, txs: [], validatorInstalled: false, executorInstalled: false };
    }
    case "installExecutor": {
      return { ...appState, executorInstalled: true };
    }
    case "installValidator": {
      return { ...appState, validatorInstalled: true };
    }
    case "newTx": {
      const { txs } = appState;
      return {
        ...appState,
        txs: [...txs, { txHash: action.value }],
      };
    }
    case "updateTx": {
      const { txs } = appState;
      const updatedTx = action.value;
      return {
        ...appState,
        txs: txs.map((tx) => (tx.txHash === updatedTx.txHash ? updatedTx : tx)),
      };
    }
    case "clearTxs": {
      return { ...appState, txs: [] };
    }
    case "update": {
      return { ...appState, ...action.value };
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

  useWatchContractEvent({
    address: SEMAPHORE_EXECUTOR_ADDRESS,
    abi: semaphoreExecutorABI,
    eventName: "InitiatedTx",
    args: {
      account: appState?.smartAccountClient?.account?.address,
    },
    onError: (err) => console.error(`watch event InitiatedTx error:`, err),
    onLogs: (logs) => logs.forEach((log) => dispatch({ type: "newTx", value: log.args.txHash! })),
  });

  // For initial state handling
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

    // smartAccountClient
    if (appState.smartAccountClient === undefined) {
      localStorage.removeItem("smartAccountAddr");
    } else {
      localStorage.setItem("smartAccountAddr", appState.smartAccountClient.account.address);
    }

    // Save the commitments
    if (appState.commitments === undefined) {
      localStorage.removeItem("commitments");
    } else {
      localStorage.setItem("commitments", JSON.stringify(appState.commitments.map((c) => c.toString())));
    }
  }, [appState]);

  // Fetching transactions
  useEffect(() => {
    let isMounted = true;

    async function fetchTxs() {
      const smartAccountClient = appState.smartAccountClient;
      if (!smartAccountClient || !smartAccountClient.account || !publicClient) return;

      const { account } = smartAccountClient;
      for (const tx of appState.txs) {
        if (tx.txHash === undefined || tx.to !== undefined) continue;

        try {
          const ecc = await getExtCallCount({
            client: publicClient,
            account,
            txHash: tx.txHash,
          });
          if (!isMounted) break;

          dispatch({
            type: "updateTx",
            value: {
              to: ecc.to,
              value: ecc.value,
              txHash: tx.txHash,
              signatureCnt: ecc.count,
            },
          });
        } catch (err) {
          console.error("getExtCallCount error:", err);
        }
      }
    }

    fetchTxs();
    return () => {
      isMounted = false;
    };
  }, [appState.smartAccountClient, appState.txs, publicClient]);

  // Fetching smartAccount related status
  useEffect(() => {
    let isMounted = true;

    async function fetchSmartAccount() {
      const smartAccountClient = appState.smartAccountClient;
      if (!publicClient || !smartAccountClient || !smartAccountClient.account) return;

      const { address } = smartAccountClient.account;

      // Check if the two modules are installed
      const isAcctInited = await publicClient.getCode({ address });
      if (isAcctInited) {
        const executorInstalled = await smartAccountClient.isModuleInstalled(getSemaphoreExecutor());
        const validatorInstalled = await smartAccountClient.isModuleInstalled(getSemaphoreValidator());
        const acctThreshold = executorInstalled
          ? await getAcctThreshold({ account: smartAccountClient.account, client: publicClient })
          : undefined;

        if (isMounted) {
          if (executorInstalled) dispatch({ type: "installExecutor" });
          if (validatorInstalled) dispatch({ type: "installValidator" });
          if (acctThreshold) dispatch({ type: "update", value: { acctThreshold: Number(acctThreshold) } });
          if (executorInstalled && validatorInstalled) dispatch({ type: "setStep", value: Step.Transactions });
        }
      }
    }

    fetchSmartAccount();
    return () => {
      isMounted = false;
    };
  }, [appState.smartAccountClient, publicClient]);

  return <AppContext.Provider value={{ appState, dispatch }}>{children}</AppContext.Provider>;
}

export function useAppContext() {
  return useContext(AppContext);
}
