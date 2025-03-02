import { baseSepolia } from "viem/chains";
import { Instructions } from "@/components/Instructions";
import { Connector } from "@/components/Connector";
import { Steps } from "@/components/Steps";

export default function Home() {
  return (
    <>
      <Connector requiredChainId={baseSepolia.id} />
      <h2 className="font-bold text-center p-4 self-center">Multi-sig Wallet with Semaphore Modules</h2>
      <Instructions />
      <Steps />
    </>
  );
}
