import * as aptos from "aptos"
import * as layerzero from "../src"
import { encodePacket, fullAddress, getBalance, hashPacket, rebuildPacketFromEvent } from "../src/utils"
import { Environment, Packet } from "../src/types"
import { findSecretKeyWithZeroPrefix } from "./utils"
import { FAUCET_URL, NODE_URL } from "../src/constants"
import { ChainStage } from "@layerzerolabs/lz-sdk"
import {Moveflow} from "../src/modules/apps/moveflow";
import {AptosAccount, AptosClient} from "aptos";
import fs from "fs";

const env = Environment.TESTNET

// retrieve the address after self deployment in local env or aptos doc in testnet env
const layerzeroDeployedAddress = "0x1759cc0d3161f1eb79f65847d4feb9d1f74fb79014698a23b16b28b9cd4c37e3";  // Testnet
const mflOwnerAddress = "0x9ae8412de465c9fbf398ea46dfd23196cf216918321688b213e5da904d281886"; // Testnet, MFL token address
const rmtEvmContractAddr = "0x0B858B1C52e49DF07fd96b87CF5DA7838f170c04";
const rmtMflTokenAddress = "0xDE3a190D9D26A8271Ae9C27573c03094A8A2c449";
const remoteChainId = 10102; // BSC

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
            const aptosCoinType = `${mflOwnerAddress}::Coins::MFL`;
            const typeinfo = await sdk.LayerzeroModule.Endpoint.getUATypeInfo(counterDeployedAddress);
            console.log("typeinfo", typeinfo);

            // Set trusted remote
            const counterSetRemoteRe = await moveflowModule.setRemote(
                counterDeployAccount,
                remoteChainId,
                Uint8Array.from(
                    Buffer.from(aptos.HexString.ensure(rmtEvmContractAddr).noPrefix(), "hex"),
                ),
            )
            console.log("counterSetRemoteRe", counterSetRemoteRe)
            const address = await moveflowModule.getRemote(remoteChainId)
            console.log("counterSetRemoteRe address", aptos.HexString.fromUint8Array(address))
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
                aptosCoinType,
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
            const uint8ArrayAptosCoin = textEncoder.encode(aptosCoinType);
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
            expect(aptCoinRe).toEqual("MFL");
        })
    })
})
