"use client";

import { Button } from "./Button";

export function InstallModulesPanel({ smartAccount }) {
  function installExecutorModule(smartAccount) {
    console.log("installExecutorModule:", smartAccount);
  }

  function installValidatorModule(smartAccount) {
    console.log("installValidatorModule:", smartAccount);
  }

  return (
    <div className="flex flex-col justify-center items-center">
      <div className="py-3">
        <Button buttonText="Install Executor Module" onClick={() => installExecutorModule(smartAccount)} />
      </div>
      <div className="py-3">
        <Button buttonText="Install Valudator Module" onClick={() => installValidatorModule(smartAccount)} />
      </div>
    </div>
  );
}
