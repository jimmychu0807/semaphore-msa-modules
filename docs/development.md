## Semaphore

- On semaphore this is how it generate a proof
  `await generateProof(identity, group, message, group.root, merkleTreeDepth)`

- On semaphore this is how it validate a proof

  ```js
  const transaction = semaphoreContract.validateProof(groupId, proof);

  await expect(transaction)
    .to.emit(semaphoreContract, "ProofValidated")
    .withArgs(
      groupId,
      proof.merkleTreeDepth,
      proof.merkleTreeRoot,
      proof.nullifier,
      proof.message,
      proof.merkleTreeRoot,
      proof.points
    );
  ```

## ERC-4337 Lifecycle

![ERC-4337 Lifecycle](./assets/4337-lifecycle.svg)

- ERC-4337: [introduction](https://www.erc4337.io/), [eip](https://eips.ethereum.org/EIPS/eip-4337)
- ERC-7579: [introduction](https://erc7579.com/), [eip](https://eips.ethereum.org/EIPS/eip-7579)

## Tasks

- have foundry ffi communicate with @semaphore/hardhat task to generateProof that

  - identiy: the private key
  - groupId
  - message: The tx: (contract function & param, smart acct, smart acct nonce)
  - group.root
  - merkleTreeDepth

- Now when reciving a validateUserOp, containing (cmt, group, tx, nonce, proof)
  - validate the proof. If the proof is invalid, reject
  - store the hash of (tx + nonce) in the mapping: acct address -> txhash -> 1
  - function interface:
    ```solidity
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
    external
        view
        override
        returns (ValidationData);
    ```

- add to signature to a tx:

  - function interface: `function`

- execute the tx:

  - function interface: TODO

- add a signature to a tx and execute:
  - function interface: TODO

## TODO & Questions

- Need to implement `Identity.verifySignature()` contract function. Check if there is any open source project that have implemented that.

- How to handle **msg.value** in validateUserOp when it is a token transfer?
