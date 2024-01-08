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
const rmtEvmContractAddr = "0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04";
const rmtEvmReceiverAddr = "0xA8c4AAE4ce759072D933bD4a51172257622eF128";
const rmtMflTokenAddress = "0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449";
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

/*               // Register MFL
            const registerMFLre = await moveflowModule.register_coin(counterDeployAccount, aptosMflCoinType);
            console.log("registerMFLre", registerMFLre);

            // Set trusted remote
            const setRemoteRe = await moveflowModule.setRemote(
                counterDeployAccount,
                remoteChainId,
                Uint8Array.from(
                    Buffer.from(aptos.HexString.ensure(rmtEvmContractAddr).noPrefix(), "hex"),
                ),
            )
            console.log("setRemoteRe", setRemoteRe)
            const address = await moveflowModule.getRemote(remoteChainId)
            console.log("setRemoteRe address", aptos.HexString.fromUint8Array(address))
            expect(aptos.HexString.fromUint8Array(address).toString().toLowerCase()).toEqual(rmtEvmContractAddr.toLowerCase());    

            // set coin map
            // (remote chain id + local coin type in byte) => remote coin address in byte
            // local coin type in byte => local coin type,
            const setCoinMapRe = await moveflowModule.setCoinMap(
                counterDeployAccount,
                remoteChainId,
                Uint8Array.from(
                    Buffer.from(aptos.HexString.ensure(rmtMflTokenAddress).noPrefix(), "hex"),
                ),
                aptosMflCoinType,
            );
            console.log("setCoinMapRe", setCoinMapRe)

            const resources = await client.getAccountResources(counterDeployedAddress);
            // console.log("resources", resources);
            const coinTypeResource = resources.find((r) => r.type === `${counterDeployedAddress}::stream::CoinTypeStore`);
            console.log("coinTypeResource", coinTypeResource);
            const _coinTypeResource  = coinTypeResource!.data as { local_coin_lookup: { handle: string },  remote_coin_lookup: { handle: string }};
            const local_coin_lookup_handle = _coinTypeResource!.local_coin_lookup.handle;
            const remote_coin_lookup_handle = _coinTypeResource!.remote_coin_lookup.handle;
            console.log(local_coin_lookup_handle, remote_coin_lookup_handle);

            // verify coin map
            const textEncoder = new TextEncoder();
            const uint8ArrayAptosCoin = textEncoder.encode(aptosMflCoinType);
            // console.log("uint8ArrayAptosCoin:", uint8ArrayAptosCoin);

            const remote_coin_lookup_re = await client.getTableItem(remote_coin_lookup_handle, {
                key_type: `${counterDeployedAddress}::stream::Path`,
                value_type: "vector<u8>",
                key: {
                    remote_chain_id: remoteChainId.toString(),
                    local_coin_byte: aptos.HexString.fromUint8Array(uint8ArrayAptosCoin).noPrefix(), 
                },
            });
            expect(remote_coin_lookup_re.toString().toLowerCase()).toEqual(rmtMflTokenAddress.toLowerCase());

            const local_coin_lookup_re = await client.getTableItem(local_coin_lookup_handle, {
                key_type: "vector<u8>",
                value_type: "0x1::type_info::TypeInfo",
                key: aptos.HexString.fromUint8Array(uint8ArrayAptosCoin).noPrefix(),
            });
            const textDecoder = new TextDecoder();
            const aptCoinModuleRe = textDecoder.decode(aptos.HexString.ensure(local_coin_lookup_re.module_name).toUint8Array());
            const aptCoinRe = textDecoder.decode(aptos.HexString.ensure(local_coin_lookup_re.struct_name).toUint8Array());
            expect(local_coin_lookup_re.account_address).toEqual(mflOwnerAddress);
            expect(aptCoinModuleRe).toEqual("Coins");
            expect(aptCoinRe).toEqual("MFL"); */
 
            const now = new Date();
            const year = now.getFullYear(); // Gets the current year (e.g., 2023)
            const month = now.getMonth() + 1; // Gets the current month (0-11, +1 to make it 1-12)
            const day = now.getDate(); // Gets the current day of the month (1-31)
            const hour = now.getHours(); // Gets the current hour (0-23)
            const strName = `${year}-${month}-${day}:${hour}`;
            const tsSecond = Math.floor(now.getTime() / 1000);
            const remark = `${tsSecond}rm`; 
            console.log(`Start creating stream: ${strName}-${remark}`);
      
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
