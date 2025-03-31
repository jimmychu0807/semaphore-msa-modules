import { blogpostUrl, srcUrl, demoUrl } from "@/utils";

export function Instructions() {
  const linkStyle = "underline underline-offset-4 decoration-dotted decoration-1";

  return (
    <div className="self-center flex flex-col w-full md:w-5/6 lg:w-2/3 text-sm gap-2 gap-y-3">
      <div>To try out the anonymous multi-sig wallet:</div>
      <ol className="list-decimal pl-6">
        <li className="my-2">
          Create a few&nbsp;
          <a className={linkStyle} href="https://docs.semaphore.pse.dev/guides/identities" target="_blank">
            Semaphore identities
          </a>
          .
        </li>
        <li className="my-2">
          Use your wallet account to create a smart account.
          <ul className="list-disc pl-6">
            <li className="my-1">
              Same wallet account address and salt nonce will always result in the same smart account address.
            </li>
            <li className="my-1">Transfer a small amount of balance to the newly created smart account.</li>
          </ul>
        </li>
        <li className="my-2">
          Install both the Executor Module and Validator Module in the smart account.
          <ul className="list-disc pl-6">
            <li className="my-1">
              Choose Semaphore identities from the select list as the&nbsp;
              <a className={linkStyle} href="https://docs.semaphore.pse.dev/guides/groups" target="_blank">
                account group
              </a>
              &nbsp;members.
            </li>
            <li className="my-1">
              Pick a proof threshold for transactions to pass. These&nbsp;
              <a className={linkStyle} href="https://docs.semaphore.pse.dev/guides/proofs" target="_blank">
                proofs
              </a>
              &nbsp;can be seen as a &quot;signature&quot; from the account members.
            </li>
            <li className="my-1">
              You could now disconnect the wallet account (in Smart Account tab) to convince yourself that you are not
              signing with the wallet.
            </li>
          </ul>
        </li>
        <li className="my-2">
          Initiate, sign, and execute balance transfer transactions between accounts with the Semaphore Identities 🎉
        </li>
      </ol>

      <div>
        To learn more about the project, check out the&nbsp;
        <a className={linkStyle} href={demoUrl} target="_blank">
          demo video
        </a>
        , read&nbsp;
        <a className={linkStyle} href={blogpostUrl} target="_blank">
          this blogpost
        </a>
        , or go directly to the&nbsp;
        <a className={linkStyle} href={srcUrl} target="_blank">
          source code
        </a>
        .
      </div>
    </div>
  );
}
