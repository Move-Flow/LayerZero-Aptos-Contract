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

# Moveflow CrossChain
## Testnet
### Aptos
* Owner: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
* Contract: 0xdbf4ebd276c84e88f0a04a4b0d26241f654ad411c250afa3a888eb3f0011486a
### BSC
* Owner: 0x569595234428B29F400a38B3E3DA09eBDBcCBC44
* Contract: 0x7F384B4a58df3e38CDF74727Cfbf9D22a65aCE1f