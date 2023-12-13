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

const env = Environment.LOCAL

// retrieve the address after self deployment in local env or aptos doc in testnet env
const layerzeroDeployedAddress = "0x0514301ce5cfca15e2d9def8629602e78f62435f0e0bb126036ac66cd810c8b3";
const oracleDeployedAddress = "0x00d03f4c1455d27aece738935c0f2ea87d109daffd4574ee578eb315d6f2a058";
describe("layerzero-aptos end-to-end test", () => {
    const majorVersion = 1,
        minorVersion = 0
/*
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
*/
    let oracleResourceAddress
    // let oracleMultisigPubkey, oracleMultisigAddress

    // relayer account
/*
    const relayerDeployAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const relayerDeployedAddress = relayerDeployAccount.address().toString()

    // executor account
    const executorAccount = new aptos.AptosAccount(findSecretKeyWithZeroPrefix(1))
    const executorAddress = executorAccount.address().toString()
*/

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

/*
    const pkStr = fs.readFileSync("./testkey").toString()
        .replace("0x", "")
        .replace("0X", "")
        .trim();
    const pkHex = Uint8Array.from(Buffer.from(pkStr, 'hex'));
    const counterDeployAccount = new AptosAccount(pkHex);
    const counterDeployedAddress = counterDeployAccount.address().toString()
*/

    const counterModule = new Counter(sdk, counterDeployedAddress)
    const moveflowModule = new Moveflow(sdk, counterDeployedAddress)

    const oracleModule = new Oracle(sdk, oracleDeployedAddress)

    const chainId = 20030

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
/*
            console.log(`layerzero deploy account: ${layerzeroDeployedAddress}`)
            console.log(`oracle deploy account: ${oracleDeployedAddress}`)
            // console.log(`oracle deploy account: ${oracleMultisigAddress}`)
            console.log(`relayer deploy account: ${executorAddress}`)
            console.log(`relayer deploy account: ${relayerDeployedAddress}`)
            console.log(`counter deploy account: ${counterDeployedAddress}`)

            // airdrop
            await faucet.fundAccount(validator1Address, 100000000000)
            await faucet.fundAccount(validator2Address, 100000000000)
            await faucet.fundAccount(relayerDeployedAddress, 100000000000)
            await faucet.fundAccount(executorAddress, 100000000000)

            await deployZro(Environment.LOCAL, layerzeroDeployAccount)
            await deployCommon(Environment.LOCAL, layerzeroDeployAccount)
            await deployMsglibV1_1(Environment.LOCAL, layerzeroDeployAccount)
            await deployMsglibV2(Environment.LOCAL, layerzeroDeployAccount)
            await deployExecutorV2(Environment.LOCAL, layerzeroDeployAccount)
            await deployLayerzero(Environment.LOCAL, chainId, layerzeroDeployAccount)
            await deployOracle(
                env,
                stage,
                oracleDeployAccount,
                layerzeroDeployedAddress,
            )
            oracleResourceAddress = await oracleModule.getResourceAddress()

            const config = getTestConfig(
                chainId,
                layerzeroDeployedAddress,
                oracleDeployedAddress,
                oracleResourceAddress,
                relayerDeployedAddress,
                executorAddress,
                {
                    [validator1Address]: true,
                    [validator2Address]: true,
                },
            )

            // wire all
            const lzTxns: Transaction[] = []
            const relayerTxns: Transaction[] = await configureRelayer(sdk, chainId, config)
            const executorTxns: Transaction[] = await configureExecutor(sdk, chainId, config)
            const oracleTxns: Transaction[] = await configureOracle(sdk, chainId, config)

            lzTxns.push(...(await configureLayerzeroWithRemote(sdk, chainId, chainId, chainId, config)))
            relayerTxns.push(...(await configureRelayerWithRemote(sdk, chainId, chainId, chainId, config)))
            executorTxns.push(...(await configureExecutorWithRemote(sdk, chainId, chainId, chainId, config))) //use same wallet
            oracleTxns.push(...(await configureOracleWithRemote(sdk, chainId, chainId, chainId, config)))

            const accounts = [layerzeroDeployAccount, relayerDeployAccount, executorAccount, oracleDeployAccount]
            const txns = [lzTxns, relayerTxns, executorTxns, oracleTxns]
            await Promise.all(
                accounts.map(async (account, i) => {
                    const txn = txns[i]
                    for (const tx of txn) {
                        await sdk.sendAndConfirmTransaction(account, tx.payload)
                    }
                }),
            )

*/



/*
            // check layerzero
            expect(await sdk.LayerzeroModule.Uln.Config.getChainAddressSize(chainId)).toEqual(32)
            const sendVersion = await sdk.LayerzeroModule.MsgLibConfig.getDefaultSendMsgLib(chainId)
            expect(sendVersion.major).toEqual(BigInt(1))
            expect(sendVersion.minor).toEqual(0)
            const receiveVersion = await sdk.LayerzeroModule.MsgLibConfig.getDefaultReceiveMsgLib(chainId)
            expect(receiveVersion.major).toEqual(BigInt(1))
            expect(receiveVersion.minor).toEqual(0)
            expect(
                Buffer.compare(
                    await sdk.LayerzeroModule.Executor.getDefaultAdapterParams(chainId),
                    sdk.LayerzeroModule.Executor.buildDefaultAdapterParams(10000),
                ) == 0,
            ).toBe(true)

            // check executor
            {
                const fee = await sdk.LayerzeroModule.Executor.getFee(executorAddress, chainId)
                expect(fee.airdropAmtCap).toEqual(BigInt(10000000000))
                expect(fee.priceRatio).toEqual(BigInt(10000000000))
                expect(fee.gasPrice).toEqual(BigInt(1))
            }

            // check relayer
            {
                const fee = await sdk.LayerzeroModule.Uln.Signer.getFee(relayerDeployedAddress, chainId)
                expect(fee.base_fee).toEqual(BigInt(100))
                expect(fee.fee_per_byte).toEqual(BigInt(1))
            }

            // check oracle
            expect(await oracleModule.isValidator(validator1Address)).toBe(true)
            expect(await oracleModule.isValidator(validator2Address)).toBe(true)
            expect(await oracleModule.getThreshold()).toEqual(2)
            {
                const fee = await sdk.LayerzeroModule.Uln.Signer.getFee(oracleResourceAddress, chainId)
                expect(fee.base_fee).toEqual(BigInt(10))
                expect(fee.fee_per_byte).toEqual(BigInt(0))
            }

            await deployCounter(
                env,
                stage,
                counterDeployAccount,
                layerzeroDeployedAddress,
            )
*/

            await faucet.fundAccount(counterDeployedAddress, 1000000000)

            await deployMoveflow(
                env,
                stage,
                counterDeployAccount,
                layerzeroDeployedAddress,
            );
        })

        let decodedParams
        test("register ua", async () => {
/*
            const createCounterRe = await counterModule.createCounter(counterDeployAccount, 0);
            console.log("createCounterRe", createCounterRe);
*/

            const moveflowInit = await moveflowModule.initialize(counterDeployAccount, counterDeployAccount.address(), counterDeployAccount.address());
            console.log("moveflowInit", moveflowInit);
            // await moveflowModule.register_coin(counterDeployAccount, '0x1::aptos_coin::AptosCoin');
        })
    })
})
