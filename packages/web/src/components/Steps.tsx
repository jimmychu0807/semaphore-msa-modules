"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from "@headlessui/react";
import { IdentityPanel } from "./IdentityPanel";
import { SmartAccountPanel } from "./SmartAccountPanel";
import { InstallModulesPanel } from "./InstallModulesPanel";
import { TransactionsPanel } from "./TransactionsPanel";

import { useAppState } from "@/hooks/useAppState";
import { type AppSmartAccountClient } from "@/utils/types";

function getLargestTabFromStep(step: string): number {
  switch (step) {
    case "setIdentity":
      return 0;
    case "setSmartAccount":
      return 1;
    case "installModules":
      return 2;
    case "transactions":
      return 3;
    default:
      return 0;
  }
}

export function Steps() {
  const account = useAccount();
  const isConnected = !!account.address;
  const { data: currentStep } = useAppState("step");
  const largestTab = getLargestTabFromStep(currentStep);
  const [smartAccountClient, setSmartAccountClient] = useState<AppSmartAccountClient>();

  const tabClassNames =
    "rounded-full py-1 px-3 font-semibold text-sm/6 focus:outline-none data-[selected]:bg-black/10 data-[hover]:bg-black/5 data-[selected]:data-[hover]:bg-black/10 data-[focus]:outline-1 data-[focus]:outline-black";

  if (!isConnected) {
    return <div className="self-center">Please connect with your wallet</div>;
  }

  return (
    <section className="self-center flex flex-col items-center w-full md:w-2/3">
      <TabGroup className="w-full">
        <TabList className="flex gap-4">
          <Tab key="identityTab" className={tabClassNames}>
            1. Set Identity
          </Tab>
          {largestTab >= 1 && (
            <Tab key="smartAccountTab" className={tabClassNames}>
              2. Set Smart Account
            </Tab>
          )}
          {largestTab >= 2 && (
            <Tab key="installModuleTab" className={tabClassNames}>
              3. Install Modules
            </Tab>
          )}
          {largestTab >= 3 && (
            <Tab key="transactions" className={tabClassNames}>
              4. Transactions
            </Tab>
          )}
        </TabList>
        <TabPanels className="mt-3">
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
