"use client";

import { type ReactNode, createContext, useContext, useReducer, useEffect, useState } from "react";
import { type Address, type PublicClient } from "viem";
import { usePublicClient, useWalletClient, useWatchContractEvent } from "wagmi";

import { getSmartAccountClient } from "@/utils";
import { type TAppContext, type TAppState, type TAppAction, Step } from "@/types";
import { Identity } from "@semaphore-protocol/identity";
import {
  SEMAPHORE_EXECUTOR_ADDRESS,
  getSemaphoreExecutor,
  getSemaphoreValidator,
  getAcctThreshold,
  getAcctMembers,
  getExtCallCount,
} from "@semaphore-msa-modules/lib";
import { semaphoreExecutorABI } from "@semaphore-msa-modules/lib/abi";

const unInitAppState: TAppState = {
  identities: [],
  nextId: 1,
  step: Step.SetIdentity,
  status: "pending",

  executorInstalled: false,
  validatorInstalled: false,

  txs: [],
};

export const AppContext = createContext<TAppContext>({
  appState: unInitAppState,
  dispatch: () => ({}),
});

// Restoring the appstate from localstorage
async function initAppState(publicClient: PublicClient | undefined): Promise<TAppState> {
  const appState: TAppState = { ...unInitAppState, status: "ready" };

  const identities = JSON.parse(window.localStorage.getItem("identities") ?? "[]");
  appState.identities = identities.map(({ key, sk }: { key: string; sk: string }) => ({
    key,
    identity: Identity.import(sk),
  }));

  appState.nextId = Number(window.localStorage.getItem("nextId") ?? "1");

  appState.step = Number(window.localStorage.getItem("step") ?? "0") as Step;

  appState.saltNonce = BigInt(window.localStorage.getItem("saltNonce") ?? "0");

  const address = window.localStorage.getItem("smartAccountAddr") as Address;
  if (address && publicClient) {
    // Restore the smart account client
    try {
      const smartAccountClient = await getSmartAccountClient({
        publicClient,
        saltNonce: appState.saltNonce,
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
    case "insertIdentity": {
      return { ...appState, identities: [...appState.identities, action.value] };
    }
    case "clearIdentity": {
      const delKey = action.value;
      return { ...appState, identities: appState.identities.filter(({ key }) => key !== delKey) };
    }
    case "clearAllIdentities": {
      return { ...appState, identities: [] };
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
      const { smartAccountClient, commitments, saltNonce, acctThreshold, ...newState } = appState;
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
    case "signTx": {
      const { txs } = appState;
      const txHash = action.value;
      return {
        ...appState,
        txs: txs.map((tx) => (tx.txHash === txHash ? { ...tx, signatureCnt: (tx.signatureCnt ?? 0) + 1 } : tx)),
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
    case "clearTx": {
      const txHash = action.value;
      return {
        ...appState,
        txs: appState.txs.filter((tx) => tx.txHash !== txHash),
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
    onError: (err) => console.error(`watching InitiatedTx event error:`, err),
    onLogs: (logs) => logs.forEach((log) => dispatch({ type: "newTx", value: log.args.txHash! })),
  });

  useWatchContractEvent({
    address: SEMAPHORE_EXECUTOR_ADDRESS,
    abi: semaphoreExecutorABI,
    eventName: "SignedTx",
    args: {
      account: appState?.smartAccountClient?.account?.address,
    },
    onError: (err) => console.error(`watching SignedTx event error:`, err),
    onLogs: (logs) => logs.forEach((log) => dispatch({ type: "signTx", value: log.args.txHash! })),
  });

  useWatchContractEvent({
    address: SEMAPHORE_EXECUTOR_ADDRESS,
    abi: semaphoreExecutorABI,
    eventName: "ExecutedTx",
    args: {
      account: appState?.smartAccountClient?.account?.address,
    },
    onError: (err) => console.error(`watching ExecutedTx event error:`, err),
    onLogs: (logs) => logs.forEach((log) => dispatch({ type: "clearTx", value: log.args.txHash! })),
  });

  // For initial state handling
  useEffect(() => {
    let isMounted = true;
    (async () => {
      if (!window || isInit) return;
      dispatch({ type: "init", value: await initAppState(publicClient) });
      if (isMounted) setInit(true);
    })();

    return () => {
      isMounted = false;
    };
  }, [isInit, setInit, publicClient]);

  // Update the smart account client wallet client setting when user connected with its wallet
  useEffect(() => {
    const address = window.localStorage.getItem("smartAccountAddr") as Address;

    if (!address || !publicClient || !walletClient?.data) return;

    let isMounted = true;
    const saltNonce = BigInt(window.localStorage.getItem("saltNonce") ?? "0");

    (async () => {
      try {
        const smartAccountClient = await getSmartAccountClient({
          publicClient,
          owners: [walletClient.data],
          saltNonce,
          address,
        });
        if (isMounted) appState.smartAccountClient = smartAccountClient;
      } catch (err) {
        console.error("Update smart account client with wallet data error:", err);
      }
    })();

    return () => {
      isMounted = false;
    };
    // Do not check for `appState` for dependencies
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [publicClient, walletClient?.data]);

  // Saving the appState in localstorage
  useEffect(() => {
    if (appState.status !== "ready") return;

    // step
    if (appState.step === undefined) {
      localStorage.removeItem("step");
    } else {
      localStorage.setItem("step", appState.step.toString());
    }

    // saltNonce
    if (appState.saltNonce === undefined) {
      localStorage.removeItem("saltNonce");
    } else {
      localStorage.setItem("saltNonce", appState.saltNonce.toString());
    }

    // smartAccountClient
    if (appState.smartAccountClient === undefined) {
      localStorage.removeItem("smartAccountAddr");
    } else {
      localStorage.setItem("smartAccountAddr", appState.smartAccountClient.account.address);
    }

    // Member commitments
    if (appState.commitments === undefined) {
      localStorage.removeItem("commitments");
    } else {
      localStorage.setItem("commitments", JSON.stringify(appState.commitments.map((c) => c.toString())));
    }
  }, [appState]);

  // saving appState.identities in localstorage
  useEffect(() => {
    if (appState.status !== "ready") return;

    localStorage.setItem(
      "identities",
      JSON.stringify(appState.identities.map(({ key, identity }) => ({ key, sk: identity.export() })))
    );

    localStorage.setItem("nextId", appState.nextId.toString());
  }, [appState.status, appState.identities, appState.nextId]);

  // Fetching smartAccount related status
  useEffect(() => {
    let isMounted = true;

    (async () => {
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
        const commitments = executorInstalled
          ? await getAcctMembers({ account: smartAccountClient.account, client: publicClient })
          : undefined;

        if (isMounted) {
          if (executorInstalled) dispatch({ type: "installExecutor" });
          if (validatorInstalled) dispatch({ type: "installValidator" });
          if (acctThreshold) dispatch({ type: "update", value: { acctThreshold: Number(acctThreshold) } });
          if (commitments) dispatch({ type: "update", value: { commitments } });
          if (executorInstalled && validatorInstalled) dispatch({ type: "setStep", value: Step.Transactions });
        }
      }
    })();

    return () => {
      isMounted = false;
    };
  }, [appState.smartAccountClient, publicClient]);

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

  return <AppContext.Provider value={{ appState, dispatch }}>{children}</AppContext.Provider>;
}

export function useAppContext() {
  return useContext(AppContext);
}
