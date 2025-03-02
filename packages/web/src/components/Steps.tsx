"use client";

import { useState } from "react";
import { type Address } from "viem";
import { useAccount } from "wagmi";
import { Tab, TabGroup, TabList, TabPanel, TabPanels } from "@headlessui/react";
import { IdentityPanel } from "./IdentityPanel";
import { SmartAccountPanel } from "./SmartAccountPanel";
import { InstallModulesPanel } from "./InstallModulesPanel";

export function Steps() {
  const account = useAccount();
  const isConnected = !!account.address;
  const [identity, setIdentity] = useState();
  const [smartAccount, setSmartAccount] = useState();

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
          {identity && (
            <Tab key="smartAccountTab" className={tabClassNames}>
              2. Set Smart Account
            </Tab>
          )}
          {identity && smartAccount && (
            <Tab key="installModuleTab" className={tabClassNames}>
              3. Install Modules
            </Tab>
          )}
        </TabList>
        <TabPanels className="mt-3">
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <IdentityPanel identity={identity} setIdentity={setIdentity} />
          </TabPanel>
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <SmartAccountPanel smartAccount={smartAccount} setSmartAccount={setSmartAccount} />
          </TabPanel>
          <TabPanel className="rounded-xl bg-black/5 p-3">
            <InstallModulesPanel smartAccount={smartAccount} />
          </TabPanel>
        </TabPanels>
      </TabGroup>
    </section>
  );
}
