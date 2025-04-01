export const abi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "_semaphore",
        type: "address",
        internalType: "contract ISemaphore",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "GROUPS",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract ISemaphoreGroups",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "SEMAPHORE",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract ISemaphore",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accountHasMember",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "cmt",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "accountMemberCount",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint8",
        internalType: "uint8",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "acctSeqNum",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "seqNum",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "acctTxCount",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    outputs: [
      {
        name: "targetAddr",
        type: "address",
        internalType: "address",
      },
      {
        name: "callData",
        type: "bytes",
        internalType: "bytes",
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "count",
        type: "uint8",
        internalType: "uint8",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "addMembers",
    inputs: [
      {
        name: "cmts",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "executeTx",
    inputs: [
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    outputs: [
      {
        name: "returnData",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getAcctMembers",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "members",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAcctSeqNum",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAcctTx",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    outputs: [
      {
        name: "ecc",
        type: "tuple",
        internalType: "struct ExtCallCount",
        components: [
          {
            name: "targetAddr",
            type: "address",
            internalType: "address",
          },
          {
            name: "callData",
            type: "bytes",
            internalType: "bytes",
          },
          {
            name: "value",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "count",
            type: "uint8",
            internalType: "uint8",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getGroupId",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "groupMapping",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "initiateTx",
    inputs: [
      {
        name: "target",
        type: "address",
        internalType: "address",
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "callData",
        type: "bytes",
        internalType: "bytes",
      },
      {
        name: "proof",
        type: "tuple",
        internalType: "struct ISemaphore.SemaphoreProof",
        components: [
          {
            name: "merkleTreeDepth",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "merkleTreeRoot",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "nullifier",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "message",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "scope",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "points",
            type: "uint256[8]",
            internalType: "uint256[8]",
          },
        ],
      },
      {
        name: "execute",
        type: "bool",
        internalType: "bool",
      },
    ],
    outputs: [
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "isInitialized",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isModuleType",
    inputs: [
      {
        name: "typeID",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "name",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "string",
        internalType: "string",
      },
    ],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "onInstall",
    inputs: [
      {
        name: "data",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "onUninstall",
    inputs: [
      {
        name: "",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "removeMember",
    inputs: [
      {
        name: "prevCmt",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "cmt",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "merkleProofSiblings",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "semaphoreValidatorAddr",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "setSemaphoreValidator",
    inputs: [
      {
        name: "target",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setThreshold",
    inputs: [
      {
        name: "newThreshold",
        type: "uint8",
        internalType: "uint8",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "signTx",
    inputs: [
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
      {
        name: "proof",
        type: "tuple",
        internalType: "struct ISemaphore.SemaphoreProof",
        components: [
          {
            name: "merkleTreeDepth",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "merkleTreeRoot",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "nullifier",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "message",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "scope",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "points",
            type: "uint256[8]",
            internalType: "uint256[8]",
          },
        ],
      },
      {
        name: "execute",
        type: "bool",
        internalType: "bool",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "thresholds",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "threshold",
        type: "uint8",
        internalType: "uint8",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "version",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "string",
        internalType: "string",
      },
    ],
    stateMutability: "pure",
  },
  {
    type: "event",
    name: "AddedMembers",
    inputs: [
      {
        name: "",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "length",
        type: "uint8",
        indexed: true,
        internalType: "uint8",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "ExecutedTx",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "InitiatedTx",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "seq",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "txHash",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RemovedMember",
    inputs: [
      {
        name: "",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "commitment",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SemaphoreExecutorInitialized",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SemaphoreExecutorUninitialized",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SetSemaphoreValidator",
    inputs: [
      {
        name: "target",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SignedTx",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "ThresholdSet",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "threshold",
        type: "uint8",
        indexed: true,
        internalType: "uint8",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "CommitmentsNotUnique",
    inputs: [],
  },
  {
    type: "error",
    name: "ExecuteTxFailure",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "targetAddr",
        type: "address",
        internalType: "address",
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "callData",
        type: "bytes",
        internalType: "bytes",
      },
    ],
  },
  {
    type: "error",
    name: "InitiateTxWithNullAddress",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidCommitment",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidInstallData",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidSemaphoreProof",
    inputs: [
      {
        name: "reason",
        type: "bytes",
        internalType: "bytes",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidSemaphoreValidator",
    inputs: [
      {
        name: "addr",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidThreshold",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "IsMemberAlready",
    inputs: [
      {
        name: "acount",
        type: "address",
        internalType: "address",
      },
      {
        name: "cmt",
        type: "uint256",
        internalType: "uint256",
      },
    ],
  },
  {
    type: "error",
    name: "LinkedList_AlreadyInitialized",
    inputs: [],
  },
  {
    type: "error",
    name: "LinkedList_EntryAlreadyInList",
    inputs: [
      {
        name: "entry",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
  },
  {
    type: "error",
    name: "LinkedList_InvalidEntry",
    inputs: [
      {
        name: "entry",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
  },
  {
    type: "error",
    name: "LinkedList_InvalidPage",
    inputs: [],
  },
  {
    type: "error",
    name: "MaxMemberReached",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "MemberCntReachesThreshold",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "MemberNotExists",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "cmt",
        type: "uint256",
        internalType: "uint256",
      },
    ],
  },
  {
    type: "error",
    name: "ModuleAlreadyInitialized",
    inputs: [
      {
        name: "smartAccount",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "NotInitialized",
    inputs: [
      {
        name: "smartAccount",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "SemaphoreValidatorIsInitialized",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "SemaphoreValidatorSetAlready",
    inputs: [],
  },
  {
    type: "error",
    name: "ThresholdNotReach",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "threshold",
        type: "uint8",
        internalType: "uint8",
      },
      {
        name: "current",
        type: "uint8",
        internalType: "uint8",
      },
    ],
  },
  {
    type: "error",
    name: "TxHasBeenInitiated",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
  },
  {
    type: "error",
    name: "TxNotFound",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
      {
        name: "txHash",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
  },
] as const;
