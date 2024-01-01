import * as aptos from "aptos"
import * as layerzero from "../src"
import { Environment, Packet } from "../src/types"
import { findSecretKeyWithZeroPrefix } from "./utils"
import { FAUCET_URL, NODE_URL } from "../src/constants"
import { ChainStage } from "@layerzerolabs/lz-sdk"
import { deployMoveflow } from "../tasks/deploy/deployMoveflow";
import {Moveflow} from "../src/modules/apps/moveflow";
import {AptosAccount, AptosClient} from "aptos";
import fs from "fs";

const env = Environment.TESTNET

// retrieve the address after self deployment in local env or aptos doc in testnet env
const layerzeroDeployedAddress = "0x1759cc0d3161f1eb79f65847d4feb9d1f74fb79014698a23b16b28b9cd4c37e3";
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

    const moveflowModule = new Moveflow(sdk, counterDeployedAddress)

    beforeAll(async () => {
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

            await deployMoveflow(
                env,
                stage,
                counterDeployAccount,
                layerzeroDeployedAddress,
            );

        })

        test("register ua", async () => {
            const moveflowInit = await moveflowModule.initialize(counterDeployAccount, counterDeployAccount.address(), counterDeployAccount.address());
            console.log("moveflowInit", moveflowInit);
            await moveflowModule.register_coin(counterDeployAccount, '0x1::aptos_coin::AptosCoin');
        })
    })
})
