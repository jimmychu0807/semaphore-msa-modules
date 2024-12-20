## Semaphore Modular Smart Contract (MSA) Validator Module

[Development Notes](./docs/development.md)

The module aims to adhere with **ERC-7579** standard ([introduction](https://erc7579.com/), [eip](https://eips.ethereum.org/EIPS/eip-7579)) and is forked from [rhinestonewtf/module-template](https://github.com/rhinestonewtf/module-template).

## Using the template

### Building modules

```shell
# Install dependencies
pnpm install

# Update ModuleKit
pnpm update rhinestonewtf/modulekit

# Build
pnpm build

# Test
pnpm test
```

### Deploying modules

1. Import your modules into the `script/DeployModule.s.sol` file.
2. Create a `.env` file in the root directory based on the `.env.example` file and fill in the variables.
3. Run the following command:

```shell
source .env && forge script script/DeployModule.s.sol:DeployModuleScript --rpc-url $DEPLOYMENT_RPC --broadcast --sender $DEPLOYMENT_SENDER --verify
```

Your module is now deployed to the blockchain and verified on Etherscan.

If the verification fails, you can manually verify it on Etherscan using the following command:

```shell
source .env && forge verify-contract --chain-id [YOUR_CHAIN_ID] --watch --etherscan-api-key $ETHERSCAN_API_KEY [YOUR_MODULE_ADDRESS] src/[PATH_TO_MODULE].sol:[MODULE_CONTRACT_NAME]
```

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.
