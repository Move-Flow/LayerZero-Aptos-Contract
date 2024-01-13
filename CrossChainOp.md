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
    * `remoteAddress`
    * `ENDPOINT_HTTP`
    * `remoteMflAddress`
  * `npx hardhat --network bsc-testnet setTrustedRemote.Aptos`, what the script should have done:
    * Mint MFL
    * Register MFL
    * Deposit MFL to cx chain pool
    * set trusted remote

## Aptos
* Init
  * Set the following variables in `sdk/tests/moveflow.setRemote.test.ts` according to deployment above and env
    * `layerzeroDeployedAddress`
    * `mflOwnerAddress`
    * `rmtEvmContractAddr`
    * `rmtMflTokenAddress`
    * `rmtEvmReceiverAddr`
    * `remoteChainId`
  * MFL Token owner transfers at least 0.1 MFL to Contract Owner.
  * Ensure the deployer's apt balance is greater than 3 apt.
  * `cd sdk; npx jest ./tests/moveflow.setRemote.test.ts`, what the script should have done：
    * Mint MFL
    * Register MFL on Moveflow contract
    * `set_coin_map`
    * `setRemote`
    * Create a stream whose receiver is an EVM user.

# CrossChain Tx
## EVM
* Withdraw from aptos chain
  * Set the following variables in `tasks/withdrawFrom.Aptos.js` according to deployment above and env
    * `streamId`
    * `remoteChainId`
  * `npx hardhat --network bsc-testnet withdrawFrom.Aptos`

# Test Helper
## Aptos
* Test crosschain withdraw
  * set the following in `npx jest ./tests/moveflow.withdraw.test.ts` 
    * `layerzeroDeployedAddress`
    * `mflOwnerAddress`
    * `rmtEvmContractAddr`
    * `streamId`
    * `remoteChainId`
  * `cd sdk; npx jest ./tests/moveflow.withdraw.test.ts`

## EVM
* Test moveflow contract
  * `npx hardhat test test/examples/Moveflow.test.js`
# Tx Data Search
## Tools
* Layerzero explorer:
  * testnet.layerzeroscan.com
* BSC explorer:
  * testnet.bscscan.com
* Aptos explorer:
  * explorer.aptoslabs.com
* EVM Tx Analysis
  * dashboard.tenderly.co
## Accounts
### Aptos
* Lz module
  * Testnet: 0x1759cc0d3161f1eb79f65847d4feb9d1f74fb79014698a23b16b28b9cd4c37e3

# FAQ
## Stuck Cx Chain Tx
* Q: How do you recover the funds in a blocked tx / retry with a new nonce
  * Is this for V1? A blocked message just means that the previous nonce is a storedPayload. Once the StoredPayload has been cleared your tx will automatically clear and execute. You can retry a storedPayload via LayerZero Scan

# Testnet Dev Address
## Testnet6
### Aptos
* Owner: 0xf31930087dbb136119bdec3e97dc6e179db11ede52a04103939e33be60fff3e8
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0xb4028600028C3966c3D7730b7e2735b031DE4B44
* MFL Token Contract: 0x6A1a221eB8c61cfa6877938FbeE8bE7290b281D0

## Testnet5
### Aptos
* Owner: 0x3619778b653e7d805f7a29fb20e880e08ee9c3dde0176d1d71c8dbaca35311f8
* MFL Token Tx: 0x27170e998c12b909e26d50d218765e8a06f6dd2db3fd9c26a36c78557d3cfc06
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0xF122Fb233fAd2832263E69fc2BF42Cbcff84D870
* MFL Token Contract: 0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449

## Testnet4
### Aptos
* Owner: 0x01a4bb54c4c053d47c9f812cc143c6a83028e2df5655d2be65dfe707b77630d4
* MFL Token Tx: 0x27170e998c12b909e26d50d218765e8a06f6dd2db3fd9c26a36c78557d3cfc06
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04
* MFL Token Contract: 0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449

## Testnet3
### Aptos
* Owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886
* MFL Token Tx: 0x27170e998c12b909e26d50d218765e8a06f6dd2db3fd9c26a36c78557d3cfc06
* MFL Token owner: 0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Moveflow Contract: 0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04
* MFL Token Contract: 0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449

## Testnet2
### Aptos
* Owner: 0x159a59a77d1219724e88293f6e60e82fcbadd7f1a61789b723266006f0044851

### BSC
* Owner: 0xA8c4AAE4ce759072D933bD4a51172257622eF128
* Contract: 0x7166bfDfC46Efdda2d2AfCa86D2b96c9b0c23fE1

## Testnet
### Aptos
* Owner: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
### BSC
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* Contract: 0x7F384B4a58df3e38CDF74727Cfbf9D22a65aCE1f

# Testnet Dev Example
### Ex1 - aptos sender sends MFL, bsc receiver receives MFL
* Create cx chain MFL stream on aptos: 0xeb0825f29a545b5d531cf95a7e66356e55379186fbcd747f4f0927309e66bb4e
* Withdraw from bsc: 0xb40c1f7461080a647f4980240db5d4ad3b45573cdb1bb8c6d97e5a7b5767cbbb
* Withdraw on aptos: 0x0eff3af781bceae660bc33a314d7a692f5f89d859ba116b9e6b1afb5e0cd6ca6
* Receiver on bsc receives MFL: 0xe59080bab28ea2c013e4ad841e2460578d76139df014e2764a71b8c85b880c4e 

