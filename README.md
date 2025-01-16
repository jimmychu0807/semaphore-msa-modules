# Semaphore Modular Smart Account Validator Module

## Overview

This module is a validator module adhere to [**ERC-7579**](https://eips.ethereum.org/EIPS/eip-7579) standard that uses [Semaphore](https://semaphore.pse.dev/) at the back to create a multi-signature owner validation. This means the smart account that incorporates this validator gains benefits:

- The smart account become a M-N multi-sig wallet controlled by members added to the [Semaphore group](https://docs.semaphore.pse.dev/guides/groups) of the smart account.
- Semaphore feature preserve the privacy of who the members are of an account. One also cannot deduce who sign a signature for that smart account, while guaranteeing that a member cannot double-sign for an account.

Development of this project is part of the [PSE Acceleration Program (**FY24-1847**)](https://github.com/privacy-scaling-explorations/acceleration-program/issues/72).

## Using the Module

### Build and Test modules

```shell
# Install dependencies
pnpm install

# Build
pnpm run build

# Test
pnpm run test
```

## ERC-4337 Lifecycle on Validation

![ERC-4337 Lifecycle](docs/assets/4337-lifecycle.svg)

- ERC-4337: [introduction](https://www.erc4337.io/), [eip](https://eips.ethereum.org/EIPS/eip-4337)
- ERC-7579: [introduction](https://erc7579.com/), [eip](https://eips.ethereum.org/EIPS/eip-7579)

### Data Structure

#### Smart Contract Storage

One key in understanding the logic of this module is to understand the key data structure it use. In terms of  the storage in the [**SemaphoreMSAValidator** contract](./src/SemaphoreMSAValidator.sol), there are:

- `groupMapping`: mapping from the smart account address to a Semaphore group
- `thresholds`: the threshold number of signature the smart account needs to collect for a transaction to be executed.
- `memberCount`: The member count of a Semaphore group. The actual member commitments are stored in the `smaphore` contract.
- `acctTxCount`: stores the transaction call data and value that are waiting to be signed, and the signatures it has collected so far. This information is stored in the data structure of **`ExtCallCount`**.
- `acctSeqNum`: The sequence number corresponding to the smart account. This value is used when generating a transaction signature to uniquely identify the corresponding transaction.

#### Signature and Calldata



### Development Approach


## Contributions

Thanks to the following folks on discussing about this project and helps along: [Saleel](https://github.com/saleel) on initiating this idea with [Semaphore Wallet](https://github.com/saleel/semaphore-wallet), [Cedoor](https://github.com/cedoor) & [Vivian](https://github.com/vplasencia) on Semaphore development and its opinion. [John Guilding](https://github.com/JohnGuilding) on the discussion and support of the project.
