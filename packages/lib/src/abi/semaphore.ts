export const abi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "_verifier",
        type: "address",
        internalType: "contract ISemaphoreVerifier",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "acceptGroupAdmin",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "addMember",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "addMembers",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitments",
        type: "uint256[]",
        internalType: "uint256[]",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "createGroup",
    inputs: [
      {
        name: "admin",
        type: "address",
        internalType: "address",
      },
      {
        name: "merkleTreeDuration",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "createGroup",
    inputs: [],
    outputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "createGroup",
    inputs: [
      {
        name: "admin",
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
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getGroupAdmin",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
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
    name: "getMerkleTreeDepth",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
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
    name: "getMerkleTreeRoot",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
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
    name: "getMerkleTreeSize",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
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
    name: "groupCounter",
    inputs: [],
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
    name: "groups",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "merkleTreeDuration",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "hasMember",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
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
    name: "indexOf",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        internalType: "uint256",
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
    name: "removeMember",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
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
    name: "updateGroupAdmin",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "newAdmin",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "updateGroupMerkleTreeDuration",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "newMerkleTreeDuration",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "updateMember",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "newIdentityCommitment",
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
    name: "validateProof",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
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
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "verifier",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract ISemaphoreVerifier",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "verifyProof",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        internalType: "uint256",
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
    type: "event",
    name: "GroupAdminPending",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "oldAdmin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newAdmin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "GroupAdminUpdated",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "oldAdmin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newAdmin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "GroupCreated",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "GroupMerkleTreeDurationUpdated",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "oldMerkleTreeDuration",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "newMerkleTreeDuration",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MemberAdded",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "index",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "merkleTreeRoot",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MemberRemoved",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "index",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "merkleTreeRoot",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MemberUpdated",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "index",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "identityCommitment",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "newIdentityCommitment",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "merkleTreeRoot",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "MembersAdded",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "startIndex",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "identityCommitments",
        type: "uint256[]",
        indexed: false,
        internalType: "uint256[]",
      },
      {
        name: "merkleTreeRoot",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "ProofValidated",
    inputs: [
      {
        name: "groupId",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "merkleTreeDepth",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "merkleTreeRoot",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "nullifier",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "message",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "scope",
        type: "uint256",
        indexed: true,
        internalType: "uint256",
      },
      {
        name: "points",
        type: "uint256[8]",
        indexed: false,
        internalType: "uint256[8]",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "LeafAlreadyExists",
    inputs: [],
  },
  {
    type: "error",
    name: "LeafCannotBeZero",
    inputs: [],
  },
  {
    type: "error",
    name: "LeafDoesNotExist",
    inputs: [],
  },
  {
    type: "error",
    name: "LeafGreaterThanSnarkScalarField",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__CallerIsNotTheGroupAdmin",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__CallerIsNotThePendingGroupAdmin",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__GroupDoesNotExist",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__GroupHasNoMembers",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__InvalidProof",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__MerkleTreeDepthIsNotSupported",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__MerkleTreeRootIsExpired",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__MerkleTreeRootIsNotPartOfTheGroup",
    inputs: [],
  },
  {
    type: "error",
    name: "Semaphore__YouAreUsingTheSameNullifierTwice",
    inputs: [],
  },
  {
    type: "error",
    name: "WrongSiblingNodes",
    inputs: [],
  },
] as const;
