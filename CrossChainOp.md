# Repo & Compile
## EVM
* repo: 
  * https://github.com/Move-Flow/lz-solidity-examples/tree/cross-chain-aptos
* Wallet Setup
  * https://github.com/Move-Flow/lz-solidity-examples/tree/cross-chain-aptos?tab=readme-ov-file#deploy-setup
* Compile:
  * npx hardhat compile
## Aptos
* repo:
  * https://github.com/Move-Flow/LayerZero-Aptos-Contract
* Wallet Setup:
  * Set PK in sdk/testkey
* Compile:
  * `cd apps/moveflow/; aptos move compile --dev --package-dir .`

# Deploy
## EVM
* Deploy to bsc testnet:
  * `npx hardhat --network bsc-testnet deploy --tags MoveflowCrosschain`

## Aptos
* Deploy to testnet:
  * Set `layerzeroDeployedAddress` in `tests/moveflow.deploy.test.ts` according to the env
  * `cd sdk; npx jest ./tests/moveflow.deploy.test.ts`, what the script should have done:
    * Deploy
    * Register UA
    * Register Aptos coin 

# CrossChain Init
## EVM
* Set trusted remote
  * Set the following variables in `tasks/setTrustedRemote.Aptos.js` according to deployment above
    * `remoteChainId`
    * `localContractAdd`
    * `remoteAddress`
    * `ENDPOINT_HTTP`
  * ` npx hardhat --network bsc-testnet setTrustedRemote.Aptos`
* Withdraw from remote chain
  * `npx hardhat --network bsc-testnet withdrawFrom.Aptos`

## Aptos
* Set trusted remote
  * Set the following variables in `tasks/setTrustedRemote.Aptos.js` according to deployment above and env
    * `layerzeroDeployedAddress`
    * `remoteEvmAddress`
    * `remoteChainId`
  * `cd sdk; npx jest ./tests/moveflow.setRemote.test.ts`
* Register remote contract

# Moveflow Address
## Testnet
### Aptos
* Owner: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
* Contract Creation: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
### BSC
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* Contract: 0x7F384B4a58df3e38CDF74727Cfbf9D22a65aCE1f

## Testnet2
### Aptos
* Owner: 0x159a59a77d1219724e88293f6e60e82fcbadd7f1a61789b723266006f0044851
* Contract Creation: 0xe183c1a56f48ffbd9fb109c1e76b7e3952061be0f65f980aa2366684ab12219b

### BSC
* Owner: 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1
* Contract: 0x7166bfDfC46Efdda2d2AfCa86D2b96c9b0c23fE1

