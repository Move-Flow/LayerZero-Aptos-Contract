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
import {AptosAccount, AptosClient} from "aptos";
import fs from "fs";

const env = Environment.TESTNET

// retrieve the address after self deployment in local env or aptos doc in testnet env
const layerzeroDeployedAddress = "0x1759cc0d3161f1eb79f65847d4feb9d1f74fb79014698a23b16b28b9cd4c37e3";  // Testnet
// const layerzeroDeployedAddress = "0x0cda58507cb13820d3376708e3a9377816daec0ae5e1debf92a251df0825ad01";
// const oracleDeployedAddress = "0x00d03f4c1455d27aece738935c0f2ea87d109daffd4574ee578eb315d6f2a058";
const remoteEvmAddress = "0x7F384B4a58df3e38CDF74727Cfbf9D22a65aCE1f";
describe("layerzero-aptos end-to-end test", () => {
    // counter account
    const counterDeployAccount = (() => {
        if(env === Environment.LOCAL)
            return new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1));
        else {
            const pkStr = fs.readFileSync("./testkey").toString()
                .replace("0x", "")
                .replace("0X", "")
                .trim();
            const pkHex = Uint8Array.from(Buffer.from(pkStr, 'hex'));
            return new AptosAccount(pkHex);
        }
    })();
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

    const chainId = 10102 // BSC

    // let signFuncWithMultipleSigners: MultipleSignFunc
    beforeAll(async () => {
        // ;[oracleMultisigPubkey, oracleMultisigAddress] = await generateMultisig(
        //     [validator1.signingKey.publicKey, validator2.signingKey.publicKey],
        //     2
        // )
        // signFuncWithMultipleSigners = makeSignFuncWithMultipleSigners(...[validator1, validator2])
        // await faucet.fundAccount(oracleMultisigAddress, 5000)
    })

    describe("deploy modules", () => {
        beforeAll(async () => {
            const stage = (() => {
                if (env === Environment.LOCAL)
                    return ChainStage.TESTNET_SANDBOX;
                else if (env === Environment.TESTNET)
                    return ChainStage.TESTNET;
                else
                    return ChainStage.MAINNET;
            })();

            if(env === Environment.LOCAL)
                await faucet.fundAccount(counterDeployedAddress, 1000000000)

/*
            await deployCounter(
                env,
                stage,
                counterDeployAccount,
                layerzeroDeployedAddress,
            )
*/

/*
            await deployMoveflow(
                env,
                stage,
                counterDeployAccount,
                layerzeroDeployedAddress,
            );
*/
        })

        let decodedParams
        test("register ua", async () => {
/*
            const createCounterRe = await counterModule.createCounter(counterDeployAccount, 0);
            console.log("createCounterRe", createCounterRe);
            const typeinfo = await sdk.LayerzeroModule.Endpoint.getUATypeInfo(counterDeployedAddress)
            console.log("typeinfo", typeinfo);
            const counterSetRemoteRe = await counterModule.setRemote(
                counterDeployAccount,
                chainId,
                Uint8Array.from(
                    Buffer.from(aptos.HexString.ensure(fullAddress(remoteEvmAddress)).noPrefix(), "hex"),
                ),
            )
            console.log("counterSetRemoteRe", counterSetRemoteRe)
            const address = await counterModule.getRemote(chainId)
            console.log("counterSetRemoteRe address", address)
*/

/*
            const moveflowInit = await moveflowModule.initialize(counterDeployAccount, counterDeployAccount.address(), counterDeployAccount.address());
            console.log("moveflowInit", moveflowInit);
            const moveflowRegCoinRe =await moveflowModule.register_coin(counterDeployAccount, '0x1::aptos_coin::AptosCoin');
            console.log("moveflowRegCoinRe", moveflowRegCoinRe)
*/
            const typeinfo = await sdk.LayerzeroModule.Endpoint.getUATypeInfo(counterDeployedAddress)
            console.log("typeinfo", typeinfo);
            const counterSetRemoteRe = await moveflowModule.setRemote(
                counterDeployAccount,
                chainId,
                Uint8Array.from(
                    Buffer.from(aptos.HexString.ensure(remoteEvmAddress).noPrefix(), "hex"),
                ),
            )
            console.log("counterSetRemoteRe", counterSetRemoteRe)
            const address = await moveflowModule.getRemote(chainId)
            console.log("counterSetRemoteRe address", address)
        })
    })
})
