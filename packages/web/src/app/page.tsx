import { Instructions } from "@/components/Instructions";
import { ActionTabs } from "@/components/ActionTabs";

export default function Home() {
  return (
    <>
      <h2 className="font-bold text-center p-4 self-center text-lg">
        Anonymous multi-sig wallet with Semaphore Modules Demo
      </h2>
      <Instructions />
      <ActionTabs />
    </>
  );
}
