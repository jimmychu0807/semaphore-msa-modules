export function Instructions() {
  return (
    <div>
      <div className="grid grid-cols-2 w-full mb-4">
        {/* 1st row */}
        <div className="font-bold text-center">Owner Flow</div>
        <div className="font-bold text-center">Member Flow</div>
        {/* 2nd row */}
        <div className="border-r-2 border-gray-200 text-sm">1. Create a Semaphore identity</div>
        <div className="ps-4 text-sm">1. Create a Semaphore identity and pass the commitment to the account owner</div>
        {/* 3rd row */}
        <div className="border-r-2 border-gray-200 text-sm">2. Create a smart account</div>
        <div className="ps-4 text-sm" />
        {/* 4th row */}
        <div className="border-r-2 border-gray-200 text-sm">3. Collect all identity commitments</div>
        <div className="ps-4 text-sm" />
        {/* 5th row */}
        <div className="border-r-2 border-gray-200 text-sm">4. Install Semaphore executor and validator modules</div>
        <div className="ps-4 text-sm" />
        {/* 6th row */}
        <div className="border-r-2 border-gray-200 text-sm" />
        <div className="ps-4 text-sm">2. Claim the smart account that you have been added as a member</div>
      </div>
      <div>
        <div className="text-sm">The following apply to both owner and members of the smart account</div>
        <ol className="list-decimal text-sm">
          <li>One user initiate a transaction</li>
          <li>Collect enough signatures from other users</li>
          <li>See the transaction carry out 🎉</li>
        </ol>
      </div>
    </div>
  );
}
