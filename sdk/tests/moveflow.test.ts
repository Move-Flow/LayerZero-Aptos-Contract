import * as aptos from "aptos"
import * as layerzero from "../src"
import { encodePacket, fullAddress, getBalance, hashPacket, rebuildPacketFromEvent } from "../src/utils"
import { Environment, Packet } from "../src/types"
import { Counter } from "../src/modules/apps/counter"
import { Oracle } from "../src/modules/apps/oracle"
import {
    deployCommon,
    deployCounter,
    deployExecutorV2,
    deployLayerzero,
    deployMsglibV1_1,
    deployMsglibV2,
    deployOracle,
    deployZro,
} from "../tasks/deploy"
import {
    configureExecutor,
    configureExecutorWithRemote,
    configureLayerzeroWithRemote,
    configureOracle,
    configureOracleWithRemote,
    configureRelayer,
    configureRelayerWithRemote,
    Transaction,
} from "../tasks/wireAll"
import { getTestConfig } from "../tasks/config/local"
import { findSecretKeyWithZeroPrefix } from "./utils"
import { FAUCET_URL, NODE_URL } from "../src/constants"
import { ChainStage } from "@layerzerolabs/lz-sdk"
import { deployMoveflow } from "../tasks/deploy/deployMoveflow";
import {Moveflow} from "../src/modules/apps/moveflow";

const env = Environment.LOCAL

describe("Moveflow layerzero-aptos end-to-end test", () => {
    const majorVersion = 1,
        minorVersion = 0
    // layerzero account
    const layerzeroDeployAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const layerzeroDeployedAddress = layerzeroDeployAccount.address().toString()

    // oracle account
    const validator1 = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const validator1Address = validator1.address().toString()
    const validator2 = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const validator2Address = validator2.address().toString()
    const oracleDeployAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const oracleDeployedAddress = oracleDeployAccount.address().toString()
    let oracleResourceAddress
    // let oracleMultisigPubkey, oracleMultisigAddress

    // relayer account
    const relayerDeployAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const relayerDeployedAddress = relayerDeployAccount.address().toString()

    // executor account
    const executorAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const executorAddress = executorAccount.address().toString()

    // counter account
    const counterDeployAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const counterDeployedAddress = counterDeployAccount.address().toString()

    // faucet
    const faucet = new aptos.FaucetClient(NODE_URL[env], FAUCET_URL[env])
    console.log(`node url: ${NODE_URL[env]}, faucet url: ${FAUCET_URL[env]}`)

    const nodeUrl = NODE_URL[env]
    const client = new aptos.AptosClient(nodeUrl)
    const sdk = new layerzero.SDK({
        provider: client,
        accounts: {
            layerzero: layerzeroDeployedAddress,
            msglib_auth: layerzeroDeployedAddress,
            msglib_v1_1: layerzeroDeployedAddress,
            msglib_v2: layerzeroDeployedAddress,
            zro: layerzeroDeployedAddress,
            executor_auth: layerzeroDeployedAddress,
            executor_v2: layerzeroDeployedAddress,
        },
    })

    const counterModule = new Counter(sdk, counterDeployedAddress)
    const moveflowModule = new Moveflow(sdk, counterDeployedAddress)

    const oracleModule = new Oracle(sdk, oracleDeployedAddress)

    const chainId = 20030

    // issue coin MFL


    // register coin MFL

    // mint coin MFL
})
