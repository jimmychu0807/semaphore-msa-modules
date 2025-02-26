# Semaphore Modular Smart Account Modules

## Overview

This project mainly consists of [a validator and an executor modules](https://eips.ethereum.org/EIPS/eip-7579#validators) adheres to [**ERC-7579**](https://eips.ethereum.org/EIPS/eip-7579) standard that uses [Semaphore](https://semaphore.pse.dev/) for proof validation. Smart accounts incorporate these modules gain the following benefits:

- The smart account behaves like a **M-of-N multi-sig wallet** controlled by members of the [Semaphore group](https://docs.semaphore.pse.dev/guides/groups) of the smart account. Proofs sent by the members are used as signatures.

- The smart accout gains Semaphore property members preserve their privacy that no one know who send the proof (signature) except they must belong to the group while guaranteeing they have not signed before.

Development of this project is supported by [PSE Acceleration Program](https://github.com/privacy-scaling-explorations/acceleration-program) (see [thread discussion](https://github.com/privacy-scaling-explorations/acceleration-program/issues/72)).

Project Code: FY24-1847

Please refer to the project packages READMEs:
- [packages/contracts](./packages/contracts): Smart contracts of the Semaphore validator and executor module.
- [packages/lib](./packages/lib): Javascript library for using Semaphore MSA modules.
- [packages/web](./packages/web): Frontend demo to interact with a smart account and semaphore MSA modules.
