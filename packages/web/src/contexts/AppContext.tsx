"use client";

import { type ReactNode, createContext, useContext, useReducer, useEffect, useState } from "react";
import { type TAppContext, type TAppState, type TAppAction, Step } from "@/utils/types";
import { Identity } from "@semaphore-protocol/identity";

const unInitAppState: TAppState = {
  identity: undefined,
  step: Step.SetIdentity,
  status: "pending",
};

export const AppContext = createContext<TAppContext>({
  appState: unInitAppState,
  dispatch: () => ({}),
});

// Restoring the appstate from localstorage
function initAppState(): TAppState {
  const appState: TAppState = { status: "ready" };

  const identitySk = window.localStorage.getItem("identitySk");
  if (identitySk) {
    appState.identity = Identity.import(identitySk);
  }

  const step = window.localStorage.getItem("step");
  if (step !== undefined) {
    appState.step = Number(step) as Step;
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
    default: {
      throw new Error(`Unknown action: ${action}`);
    }
  }
}

export function AppStateProvider({ children }: { children: ReactNode }) {
  const [appState, dispatch] = useReducer(appStateReducer, unInitAppState);
  const [isInit, setInit] = useState(false);

  useEffect(() => {
    if (!window || !setInit) return;
    if (isInit) return;

    dispatch({
      type: "init",
      value: initAppState(),
    });

    setInit(true);
  }, [isInit, setInit]);

  // Saving the appState in localstorage
  useEffect(() => {
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
  }, [appState.identity, appState.step]);

  return <AppContext.Provider value={{ appState, dispatch }}>{children}</AppContext.Provider>;
}

export function useAppContext() {
  return useContext(AppContext);
}
