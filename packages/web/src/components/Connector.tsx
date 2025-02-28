"use client";
import { useAccount, useBalance, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { Button } from "./Button";
import { formatEther } from "@/utils/clients";

export function Connector({ requiredChainId }: { requiredChainId: number }) {
  const account = useAccount();
  const balanceResult = useBalance({ address: account.address });
  const { connectors, connect } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();

  return (
    <div className="text-sm flex items-end self-center">
      {account.status === "connected" || account.status === "reconnecting" ? (
        <div>
          <div className="my-2 text-center">
            Account: {account.address}&nbsp;
            {balanceResult.isSuccess && (
              <span>
                ({formatEther(balanceResult.data.value)}&nbsp;
                {balanceResult.data.symbol})
              </span>
            )}
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
