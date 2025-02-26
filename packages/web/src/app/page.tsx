import { baseSepolia } from "viem/chains";
import { Instructions } from "@/components/Instructions";
import { Connector } from "@/components/Connector";
import { Steps } from "@/components/Steps";

export default function Home() {
  return (
    <>
      <Connector requiredChainId={baseSepolia.id} />
      <h3 className="font-bold text-center w-full">Multi-sig Wallet with Semaphore Modules</h3>
      <Instructions />
      <Steps />
    </>
  );
}
