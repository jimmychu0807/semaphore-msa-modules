export function Instructions() {
  return (
    <div className="grid grid-cols-2 grid-rows-[1fr_auto] text-sm gap-2 gap-y-6">
      <div>
        <div className="text-center py-2 font-semibold">Owner Flow</div>
        <ol className="list-decimal pl-6">
          <li>Create a Semaphore identity.</li>
          <li>Create a smart account.</li>
          <li>Collect all identity commitments.</li>
          <li>Install Semaphore executor and validator modules.</li>
        </ol>
      </div>
      <div>
        <div className="text-center py-2 font-semibold">Member Flow</div>
        <ol className="list-decimal pl-6">
          <li>Create a Semaphore identity and pass the commitment to the account owner.</li>
          <li>Claim the smart account that you have been added as a member.</li>
        </ol>
      </div>
      <div className="col-span-2 place-self-center">
        <div>
          <div>Then both the owner and members of the smart account can:</div>
          <ol className="list-decimal pl-6">
            <li>Initiate a transaction.</li>
            <li>Sign the transaction.</li>
            <li>Execute the transaction once it gets enough signatures 🎉</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
