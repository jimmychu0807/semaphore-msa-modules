"use client";

import { useAccount, useBalance, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { Button } from "./Button";
import { formatEther } from "@/utils";

export function Connector({ requiredChainId }: { requiredChainId: number }) {
  const account = useAccount();
  const { data: balance } = useBalance({ address: account.address, query: { refetchInterval: 4000 } });
  const { connectors, connect } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();

  return (
    <div className="text-sm flex items-end self-center">
      {account.status === "connected" || account.status === "reconnecting" ? (
        <div>
          <div className="my-2 text-center">
            Account: {account.address}
            <span>{balance && ` (${formatEther(balance.value)} ${balance.symbol})`}</span>
          </div>
          <div className="flex flex-row gap-x-4 justify-center">
            {account.chainId !== requiredChainId && (
              <Button buttonText="Swtich Network" onClick={() => switchChain({ chainId: requiredChainId })} />
            )}
            <Button buttonText="Disconnect" onClick={() => disconnect()} />
          </div>
        </div>
      ) : (
        <div>
          <div className="my-2 text-center">Connet Wallet</div>
          <div className="flex flex-row gap-x-4 justify-center">
            {connectors.map((c) => (
              <Button key={c.uid} buttonText={c.name} onClick={() => connect({ connector: c })} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
