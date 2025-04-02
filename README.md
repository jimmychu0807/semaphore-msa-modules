# Semaphore Modular Smart Account Modules

## Project Artifacts

- 🌐 [Project demo website](https://semaphore-msa-modules.jimmychu0807.hk/) (please connect to Base Sepolia)
- 🎥 [Project demo video](https://www.loom.com/share/0b800171a4f1491f9eedd4f555569e37?sid=0c2d3024-5652-499e-b374-218023da581b)
- 📜 [Project writeup](https://jimmychu0807.hk/semaphore-msa-modules)

## Overview

This project mainly consists of [a validator and an executor modules](https://eips.ethereum.org/EIPS/eip-7579#validators) adheres to [**ERC-7579**](https://eips.ethereum.org/EIPS/eip-7579) standard that uses [Semaphore](https://semaphore.pse.dev/) for proof validation. Smart accounts incorporate these modules gain the following benefits:

- The smart account behaves like an  **anonymous multi-sig wallet** controlled by [Semaphore group members](https://docs.semaphore.pse.dev/guides/groups) of the smart account. Proofs sent by the members are regarded as signatures.

- The smart account gains Semaphore property guaranteeing a valid proof (seen as signature) must be from a member within the group and have not signed before, while preserving the member privacy and no one could trace who send the proof from the on-chain log.

Development of this project is supported by [PSE Acceleration Program](https://github.com/privacy-scaling-explorations/acceleration-program) (see [thread discussion](https://github.com/privacy-scaling-explorations/acceleration-program/issues/72)).

Project Code: FY24-1847

Please refer to the project packages READMEs:
- [packages/contracts](./packages/contracts): Smart contracts of the Semaphore validator and executor module.
- [packages/lib](./packages/lib): Javascript library for interacting with Semaphore modular smart account modules.
- [packages/web](./packages/web): Frontend demo to interact with a smart account and semaphore MSA modules.

## Relevant Information

![ERC-4337 Lifecycle](./docs/contracts-assets/4337-lifecycle.svg)

*Source: [ERC-4337 website](https://www.erc4337.io/docs/understanding-ERC-4337/architecture)*

- [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337):  [overview](https://www.erc4337.io/)
- [ERC-7579](https://eips.ethereum.org/EIPS/eip-7579): [overview](https://erc7579.com/)
- [ERC-7780](https://eips.ethereum.org/EIPS/eip-7780)

## Acknowledgement

Thanks to the following folks on discussing about this project and helps along: 

- [Saleel P](https://github.com/saleel) on initiating this idea with [Semaphore Wallet](https://github.com/saleel/semaphore-wallet), showing me that the idea is feasible.
- [Cedoor](https://github.com/cedoor) and [Vivian Plasencia](https://github.com/vplasencia) on Semaphore development and their opinions.
- [John Guilding](https://github.com/JohnGuilding) on the discussion, support, and review of the project.
- [Rhinestone team](https://rhinestone.wtf/) and [Konrad Kopp](https://github.com/kopy-kat) support on using [ModuleKit](https://docs.rhinestone.wtf/build-modules), [ModuleSDK](https://docs.rhinestone.wtf/build-modules) and their work on ERC-7579 that make this project possible, from which I have learned a lot.
