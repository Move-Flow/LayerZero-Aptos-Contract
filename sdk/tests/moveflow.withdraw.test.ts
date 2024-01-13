import * as aptos from "aptos"
import * as layerzero from "../src"
import { encodePacket, fullAddress, getBalance, hashPacket, rebuildPacketFromEvent } from "../src/utils"
import { Environment, Packet } from "../src/types"
import { findSecretKeyWithZeroPrefix } from "./utils"
import { FAUCET_URL, NODE_URL } from "../src/constants"
import { ChainStage } from "@layerzerolabs/lz-sdk"
import {Moveflow} from "../src/modules/apps/moveflow";
import {AptosAccount, AptosClient, Types} from "aptos";
import fs from "fs";
import uint64be from 'uint64be';

const env = Environment.TESTNET

// retrieve the address after self deployment in local env or aptos doc in testnet env
const layerzeroDeployedAddress = "0x1759cc0d3161f1eb79f65847d4feb9d1f74fb79014698a23b16b28b9cd4c37e3";  // Testnet
const mflOwnerAddress = "0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886"; // Testnet, MFL token address
const rmtEvmContractAddr = "0xb4028600028C3966c3D7730b7e2735b031DE4B44";
const remoteChainId = 10102; // BSC
const streamId = 0;

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
    const counterDeployedAddress = counterDeployAccount.address().toShortString();

    // faucet
    const faucet = new aptos.FaucetClient(NODE_URL[env], FAUCET_URL[env])
    console.log(`node url: ${NODE_URL[env]}`)

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

    const moveflowModule = new Moveflow(sdk, counterDeployedAddress);

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

            if(env === Environment.LOCAL)
                await faucet.fundAccount(counterDeployedAddress, 1000000000)
        })

        test("set trusted remote", async () => {
            const aptosMflCoinType = `${mflOwnerAddress}::Coins::MFL`;
            const typeinfo = await sdk.LayerzeroModule.Endpoint.getUATypeInfo(counterDeployedAddress);
            console.log("typeinfo", typeinfo);

            // Withdraw from a stream
            const uint8Array = uint64be.encode(streamId);
            const funPayload = [0].concat(Array.from(uint8Array))
            console.log("funPayload", funPayload);

            let payload: Types.TransactionPayload_EntryFunctionPayload = {
              type: "entry_function_payload",
              function: `${counterDeployedAddress}::stream::withdraw_cross_chain_res`,
              type_arguments: [aptosMflCoinType],
              arguments: [
                remoteChainId,
                aptos.HexString.ensure(rmtEvmContractAddr).toUint8Array(),
                funPayload],
            };
            let txnRequest = await client.generateTransaction(counterDeployedAddress, payload);
            let signedTxn = await client.signTransaction(counterDeployAccount, txnRequest);
            let transactionRes = await client.submitTransaction(signedTxn);
            const withdStreamRe = await client.waitForTransactionWithResult(transactionRes.hash, {checkSuccess: true});
            console.log("withdStreamRe", withdStreamRe);
        })
    })
})
