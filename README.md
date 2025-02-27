# LayerZero Aptos

LayerZero Aptos endpoint.

## Development Guide

- [Building on LayerZero](apps/README.md)

## Setup

```shell
git submodule init
git submodule update --recursive

cargo install --path deps/aptos-core/crates/aptos
```

## Running tests

### move modules

run tests of move modules

```shell
make test
```

### SDK

to run tests of SDK, we need to launch local testnet first,

```shell
aptos node run-local-testnet --force-restart --assume-yes --with-faucet
```

then execute tests
```shell
cd sdk
npm install
npx jest ./tests/omniCounter.test.ts
npx jest ./tests/bridge.test.ts
```
# Omnicounter
## Testnet
### Fuji
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* EP: 0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706
* Contract: 0x24471f9f43447af36e606AD62e36a10FE5FD4866
### BSC
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* EP: 0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1
* Contract: 0x24471f9f43447af36e606AD62e36a10FE5FD4866