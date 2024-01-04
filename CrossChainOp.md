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
### Movelfow Contract
* Deploy to bsc testnet:
  * `npx hardhat --network bsc-testnet deploy --tags MoveflowCrosschain`
### MFL Token
* Deploy to bsc testnet:
  * `npx hardhat --network bsc-testnet deploy --tags MFLToken`
* Publish to bscscan:
  * `npx hardhat verify --network bsc-testnet <MFL_CONTRACT_ADDR>`
* Mint MFL:
  * https://testnet.bscscan.com/address/<MFL_CONTRACT_ADDR>#writeContract#F4
  
## Aptos
* Deploy to testnet:
  * Set `layerzeroDeployedAddress` in `tests/moveflow.deploy.test.ts` according to the env
  * `cd sdk; npx jest ./tests/moveflow.deploy.test.ts`, what the script should have done:
    * Deploy
    * Register UA
    * Register Aptos coin 
### MFL Token
* Deploy to testnet:
  * Set up aptos cli: https://aptos.dev/tools/aptos-cli/use-cli/cli-configuration#configuration-examples
  * Create and mint MFL token
```bash
cd apps/test-token
export APT_ACC=<YOUR ACCOUNT ADDRESS>
aptos move publish \
    --named-addresses mycoin=${APT_ACC}
aptos move run \
    --function-id 0x1::managed_coin::initialize \
    --args string:"MFL" string:"MFL" u8:8 bool:true \
    --type-args ${APT_ACC}::Coins::MFL \
    --assume-yes
aptos move run \
    --function-id 0x1::managed_coin::register \
    --type-args ${APT_ACC}::Coins::MFL \
    --assume-yes    
aptos move run \
    --function-id 0x1::managed_coin::mint \
    --args address:${APT_ACC} u64:10000000000 \
    --type-args ${APT_ACC}::Coins::MFL \
    --assume-yes    
```  

# CrossChain Init
## EVM
* Init
  * Set the following variables in `tasks/setTrustedRemote.Aptos.js` according to deployment above
    * `remoteChainId`
    * `localContractAdd`
    * `remoteAddress`
    * `ENDPOINT_HTTP`
    * `mflAddress`
    * `remoteMflAddress`
  * `npx hardhat --network bsc-testnet setTrustedRemote.Aptos`, what the script should have done:
    * Register MFL
    * Deposit MFL to cx chain pool
    * set trusted remote
* Withdraw from remote chain
  * `npx hardhat --network bsc-testnet withdrawFrom.Aptos`

## Aptos
* Set trusted remote
  * Set the following variables in `sdk/tests/moveflow.setRemote.test.ts` according to deployment above and env
    * `layerzeroDeployedAddress`
    * `mflOwnerAddress`
    * `rmtEvmContractAddr`
    * `rmtMflTokenAddress`
    * `remoteChainId`
  * `cd sdk; npx jest ./tests/moveflow.setRemote.test.ts`, what the script should have done：
    * `set_coin_map`
    * `setRemote`

# CrossChain Tx
## EVM
* 

# Moveflow Address
## Testnet4
### Aptos
* Owner: 0x0b512a1fa6a486e0876ebffbf5206fcf360300bd832c86fc76571c698e258637
* Contract Creation Tx: 0x75cee30799f3503e3ef156de58ba069586236aaab1ab1414fa4b9b8cc54dcc64
* MFL Token Tx: 0x27170e998c12b909e26d50d218765e8a06f6dd2db3fd9c26a36c78557d3cfc06
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04
* MFL Token Contract: 0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449

## Testnet3
### Aptos
* Owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886
* Contract Creation Tx: 0xadd999599717a34735482dbec58c05efef3b145a7bd52fb7f6db610967016d98
* MFL Token Tx: 0x27170e998c12b909e26d50d218765e8a06f6dd2db3fd9c26a36c78557d3cfc06
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04
* MFL Token Contract: 0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449

## Testnet2
### Aptos
* Owner: 0x159a59a77d1219724e88293f6e60e82fcbadd7f1a61789b723266006f0044851
* Contract Creation Tx: 0xe183c1a56f48ffbd9fb109c1e76b7e3952061be0f65f980aa2366684ab12219b

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Contract: 0x7166bfDfC46Efdda2d2AfCa86D2b96c9b0c23fE1

## Testnet
### Aptos
* Owner: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
* Contract Creation Tx: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
### BSC
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* Contract: 0x7F384B4a58df3e38CDF74727Cfbf9D22a65aCE1f


