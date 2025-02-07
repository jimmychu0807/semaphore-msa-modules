# Semaphore Modular Smart Account Modules - Contracts

## Using the Module

```shell
# Install dependencies
pnpm install

# Build the project
pnpm run build

# Run unit tests and integration tests
pnpm run test
```

## Developer Documentation

There are two ERC-7579 modules in this repo, namely [**SemaphoreValidator**](./src/SemaphoreValidator.sol) and [**SemaphoreExecutor**](./src/SemaphoreExecutor.sol). 

**SemaphoreValidator** is responsible for validating the signature of the UserOp is indeed a valid EdDSA signature of the UserOp hash from the public key included in the signature. The validator module checks the commitment of the public key is indeed a member of the Sempahore group of the smart account. Note this module also restricts the smart account to be able to call **SempahoreExecutor** contract and its three APIs only.

**SempahoreExecutor** has all the account states stored and provides three key APIs: **initiateTx()**, **signTx()**, and **executeTx()**. **initiateTx()** is responsible for Semaphore members of the smart account to initiate an external transaction. **signTx()** is for collecting enough proofs. The proofs could be seen as a "signature" from the members who approve the tx. Lastly, **executeTx()** is to actually trigger the execution of the transaction.

Because **SemaphoreExecutor** is an [executor module](https://eips.ethereum.org/EIPS/eip-7579#executors), the called contract will see the smart account as the `msg.sender`, not the executor contract.

There is a one-time set function **setSemaphoreValidator()** in the executor to set the associated validator. This is to ensure that a smart account uninstall the validator first before the executor. Otherwise it will render the smart account unusable.

### Smart Contract Storage

[**SemaphoreExecutor** contract](./src/SemaphoreExecutor.sol) stores the following information on-chain.

- `groupMapping`: This object maps from the smart account address to a Semaphore group.
- `thresholds`: The threshold number of proofs a particular smart account needs to collect for a transaction to be executed.
- `memberCount`: The member count of a Semaphore group. The actual member commitments are stored in the `smaphore` contract [**Lean Incremental Merkle Tree**](https://github.com/privacy-scaling-explorations/zk-kit.solidity/tree/main/packages/lean-imt) structure.
- `acctTxCount`: This object stores the transaction call data and value that are waiting to be proved (signed), and the proofs it has collected so far. This information is stored in the **`ExtCallCount`** data structure.
- `acctSeqNum`: The sequence number corresponding to a smart account. This value is used when generating a transaction signature to uniquely identify a particular transaction.

### API

After installing the two modules, the smart account can only call three functions in the executor module, **initiateTx()**, **signTx()**, and **executeTx()**. Calling other functions would be rejected in the **validateUserOp()** check.

1. **initiateTx()**: for the Semaphore member to initate a new transaction of the Smart account. This function checks the validity of the semaphore proof and corresponding parameters. It takes five paramters.

   - `target`: The target address of the transaction.
   - `value`: any balance to be used. It will be used as the `msg.value` in the actual external transaction.
   - `callData`: The call data to the target address. The first four bytes are the target function selector, and the rest function payload. For EOA value transfer, this value should be null (zero-length byte).
   - `proof`: The zero-knowledge Semaphore proof generated off-chain to prove a member signs the transaction.
   - `execute`: Boolean value to indicate if the transaction reaches the proof collection threshold, whether to execute the transaction immediately.

   An **ExtCallCount** object is created to store the user transaction call data.

   A 32-byte hash **txHash** is returned, generated from `keccak256(abi.encodePacked(seq, targetAddr, value, txCallData))`.

2. **signTx()**: for other Semaphore member to sign a previously initiated transaction. Again, it checks the Semaphore proof, if the hash and the proof are valid, the proof count is incremented.

   - `txHash`: The hash value returned from `initiatedTx()` previously, to specify the proving transaction.
   - `proof`: The zero-knowledge Semaphore proof that the transaction `txHash` corresponding to.
   - `execute`: Same as initiateTx().

3.**executeTx()**: call to execute the transaction specified by `txHash`. If the transaction hasn't collected enough proofs, it would revert.

   - `txHash`: Same as initiateTx().

### Signature and Calldata

Transactions from ERC-4337 will go through **validateUserOp()** for validation, based on **userOp**, and **userOpHash**. In validation, the key logic is to check three objects: the userOp hash (`userOpHash`), the signature (`signature`), and the target call data (`targetCallData`).

A proper userOp signature is a 160 bytes value signed by EdDSA signature scheme. The signature itself is 32 * 3 = 96 bytes, but we also prepend the identity public key uses for validation.

<img src="../../docs/contracts-assets/userop-signature.svg" alt="UserOp Signature" width="50%"/>

The `userOpHash` is 32-byte long, it is a **keccak256()** of sequence number, target address, value, and the target parameters.

For the UserOp calldata passing to `getExecOps()` in testing, it is:

<img src="../../docs/contracts-assets/userop-calldata.svg" alt="UserOp Signature" width="70%"/>

Now, when decoding the calldata from **PackedUserOperation** object in **validateUserOp()**, the above calldata is combined with other information and what we are interested started from the 100th byte, as shown below.

![calldata-packedUserOp](./docs/assets/calldata-packedUserOp.svg)

### Verifying EdDSA Signature

A Semaphore identity consists of an [EdDSA](https://en.wikipedia.org/wiki/EdDSA) public/private key pair and a [commitment](https://docs.semaphore.pse.dev/glossary#identity-commitment). Semaphore uses an [EdDSA](https://github.com/privacy-scaling-explorations/zk-kit/tree/main/packages/eddsa-poseidon) implementation based on [Baby Jubjub](https://eips.ethereum.org/EIPS/eip-2494) and [Poseidon](https://www.poseidon-hash.info/). The actual implementation is in [**zk-kit**](https://github.com/privacy-scaling-explorations/zk-kit) repository. 

We implement the identity verification logic [**Identity.verifySignature()**](https://github.com/jimmychu0807/semaphore-msa-modules/blob/4842f2a175d72e8bdd59baf8cdeb46fdefc3a8d5/src/utils/Identity.sol#L39) on-chain. We also have a **[Identity.verifySignatureFFI()](https://github.com/jimmychu0807/semaphore-msa-modules/blob/4842f2a175d72e8bdd59baf8cdeb46fdefc3a8d5/src/utils/Identity.sol#L20)** function for testing to compare the result with calling Semaphore typescript-based implementation. It relies on the Baby JubJub curve Solidity implementataion by [yondonfu](https://github.com/yondonfu/sol-baby-jubjub) with [a minor fix](https://github.com/jimmychu0807/semaphore-msa-modules/blob/4842f2a175d72e8bdd59baf8cdeb46fdefc3a8d5/src/utils/CurveBabyJubJub.sol#L4-L5).

### ERC-1271 and ERC-7780

The module is also compatible with: 

- [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271): Accepting signature from other smart contract by implementing `isValidSignatureWithSender()`.
- [ERC-7780](https://eips.ethereum.org/EIPS/eip-7780): Being a **Stateless Validator** by implementing `validateSignatureWithData()`.

### Testing

The testing code relies on [Foundry FFI](https://book.getfoundry.sh/cheatcodes/ffi) to call Semaphore typescript API to generate zero-knowledge proof and EdDSA signature.

## Relevant Information

### ERC-4337 Lifecycle on Validation

![ERC-4337 Lifecycle](../../docs/contracts-assets/4337-lifecycle.svg)

*Source: [ERC-4337 website](https://www.erc4337.io/docs/understanding-ERC-4337/architecture)*

- [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337):  [overview](https://www.erc4337.io/)
- [ERC-7579](https://eips.ethereum.org/EIPS/eip-7579): [overview](https://erc7579.com/)
- [ERC-7780](https://eips.ethereum.org/EIPS/eip-7780)

## Contributions

Thanks to the following folks on discussing about this project and helps along: 

- [Saleel P](https://github.com/saleel) on initiating this idea with [Semaphore Wallet](https://github.com/saleel/semaphore-wallet), showing me that the idea is feasible.
- [Cedoor](https://github.com/cedoor) and [Vivian Plasencia](https://github.com/vplasencia) on Semaphore development and their opinions.
- [John Guilding](https://github.com/JohnGuilding) on the discussion, support, and review of the project.
- [Konrad Kopp](https://github.com/kopy-kat) on the support of using [ModuleKit](https://github.com/rhinestonewtf/modulekit) framework which this module is built upon, and answering my question on some details of ERC-4337 standard.
