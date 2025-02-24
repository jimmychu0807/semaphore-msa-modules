import type { Abi, GetEventArgs, Log } from "viem";

export type ParsedLog = Log & {
  eventName: string | undefined;
  args: GetEventArgs<
    Abi,
    string,
    {
      EnableUnion: false;
      IndexedOnly: false;
      Required: boolean;
    }
  >;
  logIndex: number;
};

export enum TestProcess {
  InstallModules = 0,
  RunInit = 1,
  RunInitSign = 2,
  RunInitSignExecute = 3,
}
