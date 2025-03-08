"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from "@headlessui/react";
import { IdentityPanel } from "./IdentityPanel";
import { SmartAccountPanel } from "./SmartAccountPanel";
import { InstallModulesPanel } from "./InstallModulesPanel";
import { TransactionsPanel } from "./TransactionsPanel";

import { useAppContext } from "@/contexts/AppContext";
import { type AppSmartAccountClient, Step } from "@/utils/types";

export function Steps() {
  const account = useAccount();
  const isConnected = !!account.address;

  const { appState } = useAppContext();
  const { step = Step.SetIdentity } = appState;

  const [selectedTab, setSelectedTab] = useState(Number(step));

  const [smartAccountClient, setSmartAccountClient] = useState<AppSmartAccountClient>();

  useEffect(() => {
    setSelectedTab(Number(step));
  }, [step]);

  const tabClassNames =
    "rounded-full py-1 px-3 font-semibold text-sm/6 focus:outline-none data-[selected]:bg-black/10 data-[hover]:bg-black/5 data-[selected]:data-[hover]:bg-black/10 data-[focus]:outline-1 data-[focus]:outline-black";

  if (!isConnected) {
    return <div className="self-center">Please connect with your wallet</div>;
  }
  if (appState.status !== "ready") {
    return <div className="self-center">Loading...</div>;
  }

  return (
    <section className="self-center flex flex-col items-center w-full md:w-5/6 lg:w-2/3">
      <TabGroup className="w-full" selectedIndex={selectedTab} onChange={setSelectedTab}>
        <TabList className="flex justify-center gap-2">
          <Tab key="identityTab" className={tabClassNames}>
            1. Set Identity
          </Tab>
          {step !== undefined && step >= Step.SetSmartAccount && (
            <Tab key="smartAccountTab" className={tabClassNames}>
              2. Set Smart Account
            </Tab>
          )}
          {step !== undefined && step >= Step.InstallModules && (
            <Tab key="installModuleTab" className={tabClassNames}>
              3. Install Modules
            </Tab>
          )}
          {step !== undefined && step >= Step.Transactions && (
            <Tab key="transactions" className={tabClassNames}>
              4. Transactions
            </Tab>
          )}
        </TabList>
        <TabPanels className="mt-2">
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <IdentityPanel />
          </TabPanel>
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <SmartAccountPanel smartAccountClient={smartAccountClient} setSmartAccountClient={setSmartAccountClient} />
          </TabPanel>
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <InstallModulesPanel smartAccountClient={smartAccountClient} />
          </TabPanel>
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <TransactionsPanel />
          </TabPanel>
        </TabPanels>
      </TabGroup>
    </section>
  );
}
