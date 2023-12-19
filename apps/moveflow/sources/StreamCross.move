
module MoveflowCross::stream {
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::vector;
    use std::bcs;

    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};
    use aptos_std::table_with_length::{Self, TableWithLength};
    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;

    use layerzero::endpoint::{Self, UaCapability};
    use layerzero::lzapp;
    use layerzero::remote;
    use layerzero_common::serde;

    const MIN_DEPOSIT_BALANCE: u64 = 10000; // 0.0001 APT(decimals=8)
    const MIN_RATE_PER_INTERVAL: u64 = 1000; // 0.00000001 APT(decimals=8)
    const INIT_FEE_POINT: u8 = 25; // 0.25%

    const STREAM_HAS_PUBLISHED: u64 = 1;
    const STREAM_NOT_PUBLISHED: u64 = 2;
    const STREAM_PERMISSION_DENIED: u64 = 3;
    const STREAM_INSUFFICIENT_BALANCES: u64 = 4;
    const STREAM_NOT_FOUND: u64 = 5;
    const STREAM_BALANCE_TOO_LITTLE: u64 = 6;
    const STREAM_HAS_REGISTERED: u64 = 7;
    const STREAM_NO_WITHDRAW_AMOUNT: u64 = 8;
    const STREAM_NOT_START: u64 = 9;
    const STREAM_EXCEED_STOP_TIME: u64 = 10;
    const STREAM_IS_CLOSE: u64 = 11;
    const STREAM_RATE_TOO_LITTLE: u64 = 12;
    const COIN_CONF_NOT_FOUND: u64 = 13;
    const STREAM_NEW_STOP_TIME: u64 = 14;
    const STREAM_INVALID_CREATE: u64 = 15;
    const STREAM_REJECT_CLOSE: u64 = 16;
    const STREAM_REJECT_PAUSE: u64 = 17;
    const STREAM_PAUSE_STATUS: u64 = 18;
    const STREAM_NO_PAUSE_STATUS: u64 = 19;
    const STREAM_IS_STOP: u64 = 20;
    const RECIPIENT_CAN_NOT_RECEIVE: u64 = 21;
    const ERR_LENGTH_MISMATCH: u64 = 22;
    const CROSS_CHAIN_ESCROW_EXIST: u64 = 23;
    const STREAM_INSUFFICIENT_CROSS_CHAIN_FEE: u64 = 24;

    const EVENT_TYPE_CREATE: u8 = 100;
    const EVENT_TYPE_WITHDRAW: u8 = 101;
    const EVENT_TYPE_CLOSE: u8 = 102;
    const EVENT_TYPE_EXTEND: u8 = 103;
    const EVENT_TYPE_REGISTER_COIN: u8 = 104;
    const EVENT_TYPE_SET_FEE_POINT: u8 = 105;
    const EVENT_TYPE_SET_FEE_TO: u8 = 106;
    const EVENT_TYPE_SET_NEW_ADMIN: u8 = 107;
    const EVENT_TYPE_SET_NEW_RECIPIENT: u8 = 108;
    const EVENT_TYPE_PAUSE: u8 = 109;
    const EVENT_TYPE_RESUME: u8 = 110;

    // packet type
    const PT_SEND: u8 = 0;
    const PT_SEND_AND_CALL: u8 = 1;

    const SALT: vector<u8> = b"Stream::streamcrosspay";
    const CROSS_CHAIN_NATIVE_FEE: u64 = 1000000;  // 0.01 APT

    /// Event emitted when created/withdraw/closed a streampay
    struct StreamEventCrossChain has drop, store {
        id: u64,
        event_type: u8,
        sender: address,
        recipient: vector<u8>,
        deposit_amount: u64,
        remaining_amount: u64,
        extend_amount: u64,
        withdraw_amount: u64,
        pause_at: u64,
        chain_id: u64,
    }

    /// Event emitted when withdraw on a remote chain
    struct StreamEventCrossChainWithdraw has drop, store {
        id: u64,
        event_type: u8,
        sender: address,
        chain_id: u64,
    }

    struct ConfigEvent has drop, store {
        event_type: u8,
        coin_type: String,
        fee_point: u8,
        fee_recipient: address,
        modified_recipient: address,
        modified_admin: address,
    }

    /// initialize when create
    /// change when withdraw, drop when close
    struct StreamInfoCrossChain has store {
        id: u64,
        name: String,
        remark: String,
        sender: address,
        recipient: vector<u8>,
        coin_type: String,
        escrow_address: address,
        interval: u64,
        rate_per_interval: u64,
        start_time: u64,
        stop_time: u64,
        last_withdraw_time: u64,
        create_at: u64,         // time that stream is creat at.
        deposit_amount: u64,   // the amount of assert deposited this stream.
        withdrawn_amount: u64, // the amount of assert withdrawn by recipitent.
        remaining_amount: u64, // the amount of assert remained, update when withdraw.
        closed: bool,
        feature_info: FeatureInfo,
        pauseInfo: PauseInfo,
        chain_id: u64,
    }

    struct FeatureInfo has store {
        pauseable: bool,
        closeable: bool,
        recipient_modifiable: bool,
    }

    struct PauseInfo has store {
        paused: bool,
        pause_at: u64,
        acc_paused_time: u64,
    }

    struct CrosschainEscrow<phantom CoinType> has key {
        coin: Coin<CoinType>,
    }

    struct Escrow<phantom CoinType> has key {
        coin: Coin<CoinType>,
    }

    struct GlobalConfig has key {
        fee_recipient: address,
        admin: address,
        coin_configs: Table<String, CoinConfig>,
        streams_store: TableWithLength<u64, StreamInfoCrossChain>,
        input_stream: Table<vector<u8>, vector<u64>>, // Todo: temparoay storage for fronrend query
        output_stream: Table<address, vector<u64>>, // Todo: temparoay storage for fronrend query
        stream_events: EventHandle<StreamEventCrossChain>,
        stream_crosschain_wtihdraw_events: EventHandle<StreamEventCrossChainWithdraw>,
        config_events: EventHandle<ConfigEvent>
    }

    struct CoinConfig has store {
        fee_point: u8,
        coin_type: String,
        crosschain_escrow_address: address,
    }

    struct StreamUA {}

    struct Capabilities<phantom UA> has key {
        cap: UaCapability<UA>,
    }

    /// set fee_recipient and admin
    public entry fun initialize(
        owner: &signer,
        fee_recipient: address,
        admin: address,
    ) {
        let owner_addr = signer::address_of(owner);
        assert!(
            @MoveflowCross == owner_addr,
            error::permission_denied(STREAM_PERMISSION_DENIED),
        );

        assert!(
            !exists<GlobalConfig>(@MoveflowCross), error::already_exists(STREAM_HAS_PUBLISHED),
        );

        move_to(owner, GlobalConfig {
                fee_recipient,
                admin,
                coin_configs: table::new<String, CoinConfig>(),
                streams_store: table_with_length::new<u64, StreamInfoCrossChain>(),
                input_stream: table::new<vector<u8>, vector<u64>>(),
                output_stream: table::new<address, vector<u64>>(),
                stream_events: account::new_event_handle<StreamEventCrossChain>(owner),
                stream_crosschain_wtihdraw_events: account::new_event_handle<StreamEventCrossChainWithdraw>(owner),
                config_events: account::new_event_handle<ConfigEvent>(owner)
            }
        );

        let cap = endpoint::register_ua<StreamUA>(owner);
        lzapp::init(owner, cap);
        remote::init(owner);

        move_to(owner, Capabilities { cap });
    }

    /// Before sending messages on LayerZero you need to register your UA(user application).
    /// The UA type is an identifier of your application. You can use any type as UA, e.g. 0x1::MyApp::MyApp as a UA.
    public entry fun register_ua<UA>(
        owner: &signer,
    ) {
        let owner_addr = signer::address_of(owner);
        assert!(
            @MoveflowCross == owner_addr,
            error::permission_denied(STREAM_PERMISSION_DENIED),
        );

        let cap = endpoint::register_ua<UA>(owner);
        lzapp::init(owner, cap);
        remote::init(owner);

        move_to(owner, Capabilities { cap });
    }

    /// register a remote chain ID and the corresponding contract on the chain
    public entry fun register_remote_contract<CoinType>(
        admin: &signer,
        remote_chain_id: u64,
        remote_contract_addr_bytes: vector<u8>
    ) acquires GlobalConfig {
        // 1. check args
        let admin_addr = signer::address_of(admin);
        check_operator(admin_addr);

        assert!(
            @MoveflowCross == admin_addr, error::permission_denied(STREAM_PERMISSION_DENIED),
        );

        // 2. set remote remote chain ID and the corresponding contract address on the chain
        remote::set(admin, remote_chain_id, remote_contract_addr_bytes);
    }

        /// register a coin type for streampay and initialize it
    public entry fun register_coin<CoinType>(
        admin: &signer
    ) acquires GlobalConfig {
        // 1. check args
        let admin_addr = signer::address_of(admin);
        check_operator(admin_addr);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        assert!(
            can_receive_coin_transfer<CoinType>(global.fee_recipient), error::invalid_argument(RECIPIENT_CAN_NOT_RECEIVE)
        );

        // 3. create coin config
        let coin_type = type_info::type_name<CoinType>();
        assert!(
            !table::contains(&global.coin_configs, coin_type), error::invalid_state(STREAM_HAS_REGISTERED)
        );

        // create cross-chain resource account for the coin type
        let seed = bcs::to_bytes(&signer::address_of(admin));
        vector::append(&mut seed, bcs::to_bytes(&@MoveflowCross));
        vector::append(&mut seed, SALT);
        vector::append(&mut seed, *string::bytes(&coin_type));
        let (resource, _signer_cap) = account::create_resource_account(admin, seed);

        assert!(
            !exists<CrosschainEscrow<CoinType>>(signer::address_of(&resource)), error::invalid_state(CROSS_CHAIN_ESCROW_EXIST)
        );

        move_to(&resource,
                CrosschainEscrow<CoinType> {
                    coin: coin::zero<CoinType>()
                }
        );

        let new_coin_config = CoinConfig {
            fee_point: INIT_FEE_POINT,
            coin_type,
            crosschain_escrow_address: signer::address_of(&resource),
        };

        // 4. emit register coin event
        event::emit_event<ConfigEvent>(
            &mut global.config_events,
            ConfigEvent {
                event_type: EVENT_TYPE_REGISTER_COIN,
                coin_type,
                fee_point: new_coin_config.fee_point,
                fee_recipient: global.fee_recipient,
                modified_recipient: @vm_reserved,
                modified_admin: global.admin,
            },
        );

        // 5. store coin config
        table::add(&mut global.coin_configs, coin_type, new_coin_config);
    }

    /// create a stream
    public entry fun create_cross_chain<CoinType>(
        sender: &signer,
        name: String,
        remark: String,
        recipient: vector<u8>,
        deposit_amount: u64, // ex: 100,0000
        start_time: u64,
        stop_time: u64,
        interval: u64,
        pauseable: bool,
        closeable: bool,
        recipient_modifiable: bool,
        chain_id: u64,
    ) acquires GlobalConfig, Escrow {
        // 1. check args
        let sender_address = signer::address_of(sender);
        let current_time = timestamp::now_seconds();

        assert!(
            stop_time >= start_time && stop_time >= current_time, error::invalid_argument(STREAM_INVALID_CREATE)
        );

        assert!(
            deposit_amount >= MIN_DEPOSIT_BALANCE, error::invalid_argument(STREAM_BALANCE_TOO_LITTLE)
        );

        assert!(
            coin::balance<CoinType>(sender_address) >= deposit_amount, error::invalid_argument(STREAM_INSUFFICIENT_BALANCES)
        );

        // Not needed for EVM recipient
        // assert!(
        //     can_receive_coin_transfer<CoinType>(recipient), error::invalid_argument(RECIPIENT_CAN_NOT_RECEIVE)
        // );

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. escrow address
        let seed = bcs::to_bytes(&timestamp::now_microseconds());
        let stream_id = table_with_length::length(&global.streams_store);
        vector::append(&mut seed, int_to_bcs(stream_id));
        let coin_type = type_info::type_name<CoinType>();
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );

        let (resource, _signer_cap) = account::create_resource_account(sender, seed);
        let escrow_address = signer::address_of(&resource);

        assert!(
            !exists<Escrow<CoinType>>(escrow_address), STREAM_HAS_REGISTERED
        );

        move_to(
            &resource,
            Escrow<CoinType> {
                coin: coin::zero<CoinType>()
            }
        );

        // To transfer aptos to the escrow, as the native fee of cross-chain reqeust
        move_to(
            &resource,
            Escrow<AptosCoin> {
                coin: coin::zero<AptosCoin>()
            }
        );

        // 4. create stream
        let duration = (stop_time - start_time) / interval;
        let rate_per_interval: u64 = deposit_amount * 1000 / duration;
        assert!(
            interval * duration + start_time == stop_time, error::invalid_argument(STREAM_EXCEED_STOP_TIME)
        );
        assert!(
            rate_per_interval >= MIN_RATE_PER_INTERVAL, error::invalid_argument(STREAM_RATE_TOO_LITTLE)
        );

        let pauseInfo = PauseInfo{
            paused: false,
            pause_at: 0u64,
            acc_paused_time: 0u64,
        };

        let feature_info = FeatureInfo{
            pauseable,
            closeable,
            recipient_modifiable,
        };

        let stream = StreamInfoCrossChain {
            id: stream_id,
            name,
            remark,
            sender: sender_address,
            recipient,
            coin_type,
            escrow_address,
            interval,
            rate_per_interval,
            start_time,
            stop_time,
            last_withdraw_time: start_time,
            create_at: timestamp::now_seconds(),
            deposit_amount,
            withdrawn_amount: 0u64,
            remaining_amount: 0u64,
            closed: false,
            feature_info,
            pauseInfo,
            chain_id,
        };

        // 5. handle assets
        // to escrow
        let to_escrow_coin = coin::withdraw<CoinType>(sender, deposit_amount); // 97,5000
        stream.remaining_amount = coin::value(&to_escrow_coin);
        merge_coin<CoinType>(escrow_address, to_escrow_coin);
        // cross-chain fee to escrow
        let native_fee = coin::withdraw<AptosCoin>(sender, CROSS_CHAIN_NATIVE_FEE);
        stream.remaining_amount = coin::value(&native_fee);
        merge_coin<AptosCoin>(escrow_address, native_fee);

        // 6. store stream
        table_with_length::add(&mut global.streams_store, stream_id, stream);

        // 7. add output stream to sender, input stream to recipient
        add_stream_index(&mut global.output_stream, sender_address, stream_id);
        add_stream_index_cross_chain(&mut global.input_stream, recipient, stream_id);

        // 8. emit create event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream_id,
                event_type: EVENT_TYPE_CREATE,
                sender: sender_address,
                recipient,
                deposit_amount,
                remaining_amount: deposit_amount,
                extend_amount: 0,
                withdraw_amount: 0,
                pause_at: 0,
                chain_id,
            },
        );
    }

    public entry fun extend<CoinType>(
        sender: &signer,
        new_stop_time: u64,
        stream_id: u64,
    ) acquires GlobalConfig, Escrow {
        // 1. init args
        let sender_address = signer::address_of(sender);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        assert!(stream.sender == sender_address, error::invalid_argument(STREAM_PERMISSION_DENIED));
        assert!(!stream.pauseInfo.paused, error::invalid_state(STREAM_PAUSE_STATUS));
        assert!(!stream.closed, error::invalid_state(STREAM_IS_CLOSE));

        //4. calc deposit amount
        assert!(new_stop_time > stream.stop_time, error::invalid_argument(STREAM_NEW_STOP_TIME));
        let duration = (new_stop_time - stream.stop_time) / stream.interval;
        let deposit_amount = duration * stream.rate_per_interval / 1000;
        assert!(
            stream.interval * duration + stream.stop_time == new_stop_time, error::invalid_argument(STREAM_EXCEED_STOP_TIME)
        );

        // 5. handle assets
        // to escrow
        assert!(
            coin::balance<CoinType>(sender_address) >= deposit_amount,
            error::invalid_argument(STREAM_INSUFFICIENT_BALANCES)
        );
        let to_escrow_coin = coin::withdraw<CoinType>(sender, deposit_amount); // 97,5000
        merge_coin<CoinType>(stream.escrow_address, to_escrow_coin);

        // 6. update stream stats
        stream.stop_time = new_stop_time;
        stream.remaining_amount = stream.remaining_amount + deposit_amount;
        stream.deposit_amount = stream.deposit_amount + deposit_amount;

        // 7. emit extend event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream_id,
                event_type: EVENT_TYPE_EXTEND,
                sender: stream.sender,
                recipient: stream.recipient,
                deposit_amount: stream.deposit_amount,
                remaining_amount: stream.remaining_amount,
                extend_amount: deposit_amount,
                withdraw_amount: 0,
                pause_at: 0,
                chain_id: stream.chain_id,
            },
        );
    }

    public entry fun close<CoinType>(
        sender: &signer,
        stream_id: u64,
    ) acquires GlobalConfig, Escrow, Capabilities {
        // 1. init args
        let sender_address = signer::address_of(sender);
        // let current_time = timestamp::now_seconds();

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow(&global.streams_store, stream_id);
        // assert!(current_time < stream.stop_time, error::invalid_state(STREAM_IS_STOP));
        assert!(closeable(stream, sender_address), error::invalid_argument(STREAM_REJECT_CLOSE));
        assert!(!stream.closed, error::invalid_state(STREAM_IS_STOP));
        assert!(!stream.pauseInfo.paused, error::invalid_state(STREAM_PAUSE_STATUS));

        // 4. withdraw
        let coin_type = type_info::type_name<CoinType>();
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );
        let coin_config = table::borrow(&global.coin_configs, coin_type);
        if (can_receive_coin_transfer<CoinType>(coin_config.crosschain_escrow_address)){
            withdraw_<CoinType>(stream_id);
        };
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);

        // 5. handle assets
        let escrow_coin = borrow_global_mut<Escrow<CoinType>>(stream.escrow_address);
        let reback_amount = coin::value(&escrow_coin.coin);
        coin::deposit(stream.sender, coin::extract(&mut escrow_coin.coin, reback_amount));

        // 6. update stream stats
        stream.remaining_amount = 0;
        stream.closed = true;

        // 7. emit close event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream_id,
                event_type: EVENT_TYPE_CLOSE,
                sender: stream.sender,
                recipient: stream.recipient,
                deposit_amount: stream.deposit_amount,
                remaining_amount: stream.remaining_amount,
                extend_amount: 0,
                withdraw_amount: 0,
                pause_at: 0,
                chain_id: stream.chain_id,
            },
        );
    }

    // Todo: how to use lz_receive_types
    public fun lz_receive_types(_src_chain_id: u64, _src_address: vector<u8>, _payload: vector<u8>) : vector<type_info::TypeInfo> {
        vector::empty<type_info::TypeInfo>()
    }

    public entry fun lz_receive<CoinType>(chain_id: u64, src_address: vector<u8>, payload: vector<u8>) acquires GlobalConfig, Escrow, Capabilities {
        withdraw_cross_chain_res<CoinType>(chain_id, src_address, payload);
    }


    public entry fun withdraw_cross_chain_res<CoinType>(
        chain_id: u64, src_address: vector<u8>, payload: vector<u8>
    ) acquires GlobalConfig, Escrow, Capabilities{
        let stream_id: u64 = serde::deserialize_u64(&payload);

        // 1. init args
        let current_time = timestamp::now_seconds();

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        assert!(current_time > stream.start_time, error::invalid_argument(STREAM_NOT_START));
        assert!(!stream.pauseInfo.paused, error::invalid_state(STREAM_PAUSE_STATUS));
        assert!(!stream.closed, error::invalid_state(STREAM_IS_CLOSE));
        assert!(stream.remaining_amount > 0, error::invalid_argument(STREAM_INSUFFICIENT_BALANCES));

        let delta = delta_of(current_time, stream);
        assert!(delta > 0, error::invalid_argument(STREAM_NO_WITHDRAW_AMOUNT));

        withdraw_<CoinType>(stream_id);
    }

    public fun quote_fee(dst_chain_id: u64, pay_in_zro: bool, payload_size: u64, adapter_params: vector<u8>, msglib_params: vector<u8>): (u64, u64) {
        endpoint::quote_fee(@MoveflowCross, dst_chain_id, payload_size, pay_in_zro, adapter_params, msglib_params)
    }

    fun withdraw_<CoinType>(
        stream_id: u64
    ) acquires GlobalConfig, Escrow, Capabilities {
        // 1. init args
        let current_time = timestamp::now_seconds();

        // 2. get handle
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        let coin_type = type_info::type_name<CoinType>();
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );
        let coin_config = table::borrow(&global.coin_configs, coin_type);

        // 3. calc withdraw amount
        let delta = delta_of(current_time, stream);
        if (delta == 0){
            return
        };

        let withdraw_amount;
        let withdraw_time;
        if (current_time < stream.stop_time) {
            withdraw_amount = stream.rate_per_interval * delta / 1000;
            withdraw_time = stream.last_withdraw_time + delta * stream.interval + stream.pauseInfo.acc_paused_time;
        } else {
            withdraw_amount = stream.remaining_amount;
            withdraw_time = stream.stop_time;
        };

        // 4. handle assets
        // Borrow from the stream's escrow
        let escrow_coin = borrow_global_mut<Escrow<CoinType>>(stream.escrow_address);
        assert!(
            withdraw_amount <= stream.remaining_amount && withdraw_amount <= coin::value(&escrow_coin.coin),
            error::invalid_argument(STREAM_INSUFFICIENT_BALANCES),
        );

        let (fee_num, to_recipient_amt) = calculate_fee(withdraw_amount, coin_config.fee_point);
        // fee
        aptos_account::deposit_coins<CoinType>(
            global.fee_recipient, 
            coin::extract(&mut escrow_coin.coin, fee_num)
        );

        //withdraw amount to recipient crosschain // Todo: use stargate
        // transfer fund to the coin's cross-chain escrow
        aptos_account::deposit_coins<CoinType>(
            coin_config.crosschain_escrow_address,
            coin::extract(&mut escrow_coin.coin, to_recipient_amt)
        );
        // crosschain request: asset on the remote chains's escrow will be transferred to the remote chains' recipient
        let cap = borrow_global<Capabilities<StreamUA>>(@MoveflowCross);
        let dst_contract_address = remote::get(@MoveflowCross, stream.chain_id);
        let payload = vector::empty<u8>();
        serde::serialize_u8(&mut payload, PT_SEND);
        serde::serialize_vector(&mut payload, stream.recipient);
        serde::serialize_vector(&mut payload, *string::bytes(&coin_type));
        serde::serialize_u64(&mut payload, withdraw_amount);

        // Borrow cross-chain fee from the stream's escrow
        let (native_fee, _) = quote_fee(stream.chain_id, false, vector::length(&payload), vector::empty<u8>(), vector::empty<u8>());
        let native_fee_coin = borrow_global_mut<Escrow<AptosCoin>>(stream.escrow_address);
        assert!(
            native_fee >= coin::value(&native_fee_coin.coin),
            error::invalid_argument(STREAM_INSUFFICIENT_CROSS_CHAIN_FEE),
        );

        // Todo: set adapter_params dynamically
        let (_, refund) = lzapp::send(stream.chain_id, dst_contract_address, payload, coin::extract(&mut native_fee_coin.coin, native_fee),
                                                        vector::empty<u8>(), vector::empty<u8>(), &cap.cap);
        coin::deposit<AptosCoin>(stream.escrow_address, refund);

        // 5. update stream stats
        stream.withdrawn_amount = stream.withdrawn_amount + withdraw_amount;
        stream.remaining_amount = stream.remaining_amount - withdraw_amount;
        stream.last_withdraw_time = withdraw_time;
        stream.pauseInfo.acc_paused_time = 0;

        // 6. emit withdraw event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream.id,
                event_type: EVENT_TYPE_WITHDRAW,
                sender: stream.sender,
                recipient: stream.recipient,
                deposit_amount: stream.deposit_amount,
                remaining_amount: stream.remaining_amount,
                extend_amount: 0,
                withdraw_amount,
                pause_at: 0,
                chain_id: stream.chain_id,
            },
        );
    }

    public entry fun withdraw_cross_chain_req<UA> (
        account: &signer,
        chain_id: u64,
        fee: u64,
        adapter_params: vector<u8>, // default to empty
        stream_id: u64,
    ) acquires Capabilities, GlobalConfig {
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let fee_in_coin = coin::withdraw<AptosCoin>(account, fee);
        let signer_addr = signer::address_of(account);

        let cap = borrow_global<Capabilities<UA>>(signer_addr);
        let dst_address = remote::get(@MoveflowCross, chain_id);
        let payload_bytes = vector::empty();
        serde::serialize_u64(&mut payload_bytes, stream_id);
        let (_, refund) = lzapp::send(chain_id, dst_address, payload_bytes, fee_in_coin, adapter_params, vector::empty<u8>(), &cap.cap);

        coin::deposit(signer_addr, refund);

        event::emit_event<StreamEventCrossChainWithdraw>(
            &mut global.stream_crosschain_wtihdraw_events,
            StreamEventCrossChainWithdraw {
                id: stream_id,
                event_type: EVENT_TYPE_WITHDRAW,
                sender: signer_addr,
                chain_id,
            },
        );
    }

    public entry fun pause<CoinType>(
        sender: &signer,
        stream_id: u64,
    ) acquires GlobalConfig, Escrow, Capabilities {
        // 1. init args
        let sender_address = signer::address_of(sender);
        let current_time = timestamp::now_seconds();

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        assert!(current_time < stream.stop_time, error::invalid_state(STREAM_IS_STOP));
        assert!(pauseable(stream, sender_address), error::invalid_argument(STREAM_REJECT_PAUSE));
        assert!(!stream.pauseInfo.paused, error::invalid_state(STREAM_PAUSE_STATUS));
        assert!(!stream.closed, error::invalid_state(STREAM_IS_CLOSE));

        // 4. modify pause info
        stream.pauseInfo.paused = true;
        stream.pauseInfo.pause_at = current_time;

        // 5. emit pause event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream.id,
                event_type: EVENT_TYPE_PAUSE,
                sender: stream.sender,
                recipient: stream.recipient,
                deposit_amount: stream.deposit_amount,
                remaining_amount: stream.remaining_amount,
                extend_amount: 0,
                withdraw_amount: 0,
                pause_at: current_time,
                chain_id: stream.chain_id,
            },
        );

        // 6. withdraw
        withdraw_<CoinType>(stream_id);
    }

    public entry fun resume(
        sender: &signer,
        stream_id: u64,
    ) acquires GlobalConfig {
        // 1. init args
        let sender_address = signer::address_of(sender);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        assert!(pauseable(stream, sender_address), error::invalid_argument(STREAM_REJECT_PAUSE));
        assert!(stream.pauseInfo.paused, error::invalid_state(STREAM_NO_PAUSE_STATUS));
        assert!(!stream.closed, error::invalid_state(STREAM_IS_CLOSE));

        // 5. modify pause info
        let current_time = timestamp::now_seconds();
        if (current_time > stream.start_time){
            let paused_time;
            if (stream.pauseInfo.pause_at < stream.start_time) {
                paused_time = current_time - stream.start_time
            }else{
                paused_time = current_time - stream.pauseInfo.pause_at;
            };

            stream.pauseInfo.acc_paused_time = stream.pauseInfo.acc_paused_time + paused_time;
            stream.stop_time = stream.stop_time + paused_time;
        };

        stream.pauseInfo.paused = false;
        stream.pauseInfo.pause_at = 0u64;

        // 6. emit resume
        // event
        event::emit_event<StreamEventCrossChain>(
            &mut global.stream_events,
            StreamEventCrossChain {
                id: stream.id,
                event_type: EVENT_TYPE_RESUME,
                sender: stream.sender,
                recipient: stream.recipient,
                deposit_amount: stream.deposit_amount,
                remaining_amount: stream.remaining_amount,
                extend_amount: 0,
                withdraw_amount: 0,
                pause_at: 0,
                chain_id: stream.chain_id,
            },
        );
    }

    /// call by  owner
    /// set new fee point
    public entry fun set_fee_point<CoinType>(
        owner: &signer,
        new_fee_point: u8,
    ) acquires GlobalConfig {
        // 1. check args
        let operator_address = signer::address_of(owner);
        check_operator(operator_address);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. get coin config
        let coin_type = type_info::type_name<CoinType>();
        assert_non_exist_coin_conf(global, coin_type);
        let coin_config = table::borrow_mut(&mut global.coin_configs, coin_type);

        // 4. modify
        coin_config.fee_point = new_fee_point;

        // 5. emit event
        event::emit_event<ConfigEvent>(
            &mut global.config_events,
            ConfigEvent {
                event_type: EVENT_TYPE_SET_FEE_POINT,
                coin_type: coin_config.coin_type,
                fee_point: coin_config.fee_point,
                fee_recipient: global.fee_recipient,
                modified_recipient: @vm_reserved,
                modified_admin: global.admin,
            },
        );
    }

    /// set new fee recipient
    public entry fun set_fee_recipient(
        owner: &signer,
        new_fee_recipient: address,
    ) acquires GlobalConfig {
        // 1. check args
        let operator_address = signer::address_of(owner);
        check_operator(operator_address);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. modify
        global.fee_recipient = new_fee_recipient;

        // 4. emit event
        event::emit_event<ConfigEvent>(
            &mut global.config_events,
            ConfigEvent {
                event_type: EVENT_TYPE_SET_FEE_TO,
                coin_type: utf8(b""),
                fee_point: 0,
                fee_recipient: global.fee_recipient,
                modified_recipient: @vm_reserved,
                modified_admin: global.admin,
            },
        );
    }

    /// set new admin
    public entry fun set_new_admin(
        owner: &signer,
        new_admin: address,
    ) acquires GlobalConfig {
        // 1. check args
        let operator_address = signer::address_of(owner);
        check_operator(operator_address);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. modify
        global.admin = new_admin;

        // 5. emit event
        event::emit_event<ConfigEvent>(
            &mut global.config_events,
            ConfigEvent {
                event_type: EVENT_TYPE_SET_NEW_ADMIN,
                coin_type: utf8(b""),
                fee_point: 0,
                fee_recipient: global.fee_recipient,
                modified_recipient: @vm_reserved,
                modified_admin: global.admin,
            },
        );
    }

    /// set new recipient // Todo: what's @vm_reserve, replace with vector<u8>?
    /*
    public entry fun set_new_recipient(
        owner: &signer,
        stream_id: u64,
        new_recipient: vector<u8>,
    ) acquires GlobalConfig {
        // 1. init args
        let operator_address = signer::address_of(owner);

        // 2. get global
        assert_non_exist_global_config();
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);

        // 3. check stream stats
        assert_non_exist_stream(global, stream_id);
        let stream = table_with_length::borrow_mut(&mut global.streams_store, stream_id);
        assert!(recipient_modifiable(stream, operator_address), error::invalid_argument(STREAM_PERMISSION_DENIED));

        // 4. modify
        stream.recipient = new_recipient;

        // 5. modify input_stream index
        del_stream_index(&mut global.input_stream, operator_address, stream_id);
        add_stream_index(&mut global.input_stream, new_recipient, stream_id);

        // 6. emit event
        event::emit_event<ConfigEvent>(
            &mut global.config_events,
            ConfigEvent {
                event_type: EVENT_TYPE_SET_NEW_RECIPIENT,
                coin_type: utf8(b""),
                fee_point: 0,
                fee_recipient: global.fee_recipient,
                modified_recipient: new_recipient,
                modified_admin: global.admin,
            },
        );
    }
    */

    ///intenal function
    fun calculate_fee(
        withdraw_amount: u64,
        fee_point: u8,
    ): (u64, u64) {
        let fee = withdraw_amount * (fee_point as u64) / 10000;

        // never overflow
        (fee, withdraw_amount - fee)
    }

    fun delta_of(withdraw_time: u64, stream: &StreamInfoCrossChain) : u64 {
        if(withdraw_time < stream.last_withdraw_time + stream.pauseInfo.acc_paused_time){
            return 0u64
        };

        (withdraw_time - stream.last_withdraw_time - stream.pauseInfo.acc_paused_time) / stream.interval
    }

    fun closeable(stream: &StreamInfoCrossChain, sender: address): bool {
        stream.sender == sender && stream.feature_info.closeable
    }

    fun pauseable(stream: &StreamInfoCrossChain, sender: address): bool {
        stream.sender == sender && stream.feature_info.pauseable
    }

    fun recipient_modifiable(stream: &StreamInfoCrossChain, sender: address): bool {
        // stream.recipient == sender && stream.feature_info.recipient_modifiable // Todo:
        false
    }

    fun check_operator(
        operator_address: address
    ) acquires GlobalConfig {
        assert!(
            admin() == operator_address || @MoveflowCross == operator_address, error::permission_denied(STREAM_PERMISSION_DENIED),
        );
    }

    fun assert_non_exist_global_config() {
        assert!(
            exists<GlobalConfig>(@MoveflowCross), error::not_found(STREAM_NOT_PUBLISHED),
        );
    }

    fun assert_non_exist_stream(global: &GlobalConfig, stream_id: u64) {
        assert!(
            table_with_length::contains(&global.streams_store, stream_id), error::not_found(STREAM_NOT_FOUND),
        );
    }

    fun assert_non_exist_coin_conf(global: &GlobalConfig, coin_type: String) {
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );
    }

    fun merge_coin<CoinType>(
        resource: address,
        coin: Coin<CoinType>
    ) acquires Escrow {
        let escrow = borrow_global_mut<Escrow<CoinType>>(resource);
        coin::merge(&mut escrow.coin, coin);
    }

    fun add_stream_index(stream_table: &mut Table<address, vector<u64>>, key_address: address, stream_id: u64 ) {
        if (!table::contains(stream_table, key_address)){
            table::add(
                stream_table,
                key_address,
                vector::empty<u64>(),
            )
        };

        let sender_stream = table::borrow_mut(stream_table, key_address);
        vector::push_back(sender_stream, stream_id);
    }

    fun add_stream_index_cross_chain(stream_table: &mut Table<vector<u8>, vector<u64>>, key_address: vector<u8>, stream_id: u64 ) {
        if (!table::contains(stream_table, key_address)){
            table::add(
                stream_table,
                key_address,
                vector::empty<u64>(),
            )
        };

        let sender_stream = table::borrow_mut(stream_table, key_address);
        vector::push_back(sender_stream, stream_id);
    }

    fun del_stream_index(stream_table: &mut Table<address, vector<u64>>, key_address: address, stream_id: u64) {
        if (table::contains(stream_table, key_address)){
            let sender_stream = table::borrow_mut(stream_table, key_address);
            let i = 0;
            while (i < vector::length(sender_stream)){
                if (*vector::borrow(sender_stream, i) == stream_id){
                    break
                };
                i = i + 1;
            };
            vector::remove(sender_stream, i);
        };
    }

    fun can_receive_coin_transfer<CoinType>(account: address): bool {
        coin::is_account_registered<CoinType>(account) || 
            aptos_account::can_receive_direct_coin_transfers(account)
    }

    const NUM_VEC: vector<u8> = b"0123456789";
    fun int_to_bcs(_n: u64): vector<u8> {
        let v = _n;
        let str_b = b"";
        if(v > 0) {
            while (v > 0) {
                let rest = v % 10;
                v = v / 10;
                vector::push_back(&mut str_b, *vector::borrow(&NUM_VEC, rest));
            };
            vector::reverse(&mut str_b);
        } else {
            vector::append(&mut str_b, b"0");
        };
        str_b
    }

    // public views for global config start
    #[view]
    public fun admin(): address acquires GlobalConfig {
        assert!(
            exists<GlobalConfig>(@MoveflowCross), error::not_found(STREAM_NOT_PUBLISHED),
        );
        borrow_global<GlobalConfig>(@MoveflowCross).admin
    }

    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::managed_coin;

    #[test_only]
    struct FakeMoney {}

    #[test(account = @0x1, owner= @MoveflowCross, admin = @0x2)]
    fun test(account: signer, owner: signer, admin: signer) acquires GlobalConfig, Escrow {

        timestamp::set_time_has_started_for_testing(&account);

        let owner_addr = signer::address_of(&owner);
        account::create_account_for_test(owner_addr);
        debug::print(&owner_addr);
        let admin_addr = signer::address_of(&admin);
        account::create_account_for_test(admin_addr);
        debug::print(&admin_addr);
        let account_addr = signer::address_of(&account);
        account::create_account_for_test(account_addr);
        debug::print(&account_addr);

        let name = b"Fake money";
        let symbol = b"FMD";

        managed_coin::initialize<FakeMoney>(&owner, name, symbol, 8, false);
        managed_coin::register<FakeMoney>(&account);
        managed_coin::register<FakeMoney>(&admin);
        managed_coin::register<FakeMoney>(&owner);
        managed_coin::mint<FakeMoney>(&owner, admin_addr, 100000);
        assert!(coin::balance<FakeMoney>(admin_addr) == 100000, 0);

        //initialize
        assert!(!exists<GlobalConfig>(@MoveflowCross), 1);
        let recipient = owner_addr;
        initialize(&owner, recipient, admin_addr);
        assert!(exists<GlobalConfig>(@MoveflowCross), 2);

        //register
        register_coin<FakeMoney>(&admin);
        assert!(!exists<Escrow<FakeMoney>>(admin_addr), 3);
        assert!(coin_type<FakeMoney>() == type_info::type_name<FakeMoney>(), 4);
        assert!(fee_point<FakeMoney>() == INIT_FEE_POINT, 5);

        //create
        create<FakeMoney>(
            &admin,
            utf8(b"test"),
            utf8(b"test"),
            recipient,
            60000,
            10000,
            10050,
            10,
            true,
            true,
            true
        );
        assert!(coin::balance<FakeMoney>(admin_addr) == 40000, 0);
        // get _config
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());

        let _stream = table_with_length::borrow(&global.streams_store, 0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let escrow_coin = borrow_global<Escrow<FakeMoney>>(_stream.escrow_address);
        debug::print(&coin::value(&escrow_coin.coin));
        assert!(_stream.recipient == recipient, 0);
        assert!(_stream.sender == admin_addr, 0);
        assert!(_stream.start_time == 10000, 0);
        assert!(_stream.stop_time == 10050, 0);
        assert!(_stream.deposit_amount == 60000, 0);
        assert!(_stream.remaining_amount == coin::value(&escrow_coin.coin), 0);
        debug::print(&_stream.rate_per_interval);
        debug::print(&(_stream.deposit_amount * 1000/(_stream.stop_time - _stream.start_time)));
        assert!(_stream.rate_per_interval ==
            _stream.deposit_amount * 1000/((_stream.stop_time - _stream.start_time)/_stream.interval), 0);
        assert!(_stream.last_withdraw_time == 10000, 0);

        //wthidraw
        let beforeWithdraw = coin::balance<FakeMoney>(recipient);
        debug::print(&coin::balance<FakeMoney>(recipient));

        timestamp::update_global_time_for_test_secs(10010);
        withdraw<FakeMoney>(0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        assert!(_stream.last_withdraw_time == 10010, 0);
        assert!(coin::balance<FakeMoney>(recipient) == beforeWithdraw + 60000/5 * 1, 0);

        timestamp::fast_forward_seconds(10);
        withdraw<FakeMoney>(0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        assert!(_stream.last_withdraw_time == 10020, 0);
        assert!(coin::balance<FakeMoney>(recipient) == beforeWithdraw + 60000/5 * 2, 0);

        timestamp::fast_forward_seconds(10);
        withdraw<FakeMoney>(0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        assert!(_stream.last_withdraw_time == 10030, 0);
        assert!(coin::balance<FakeMoney>(recipient) == beforeWithdraw + 60000/5 * 3, 0);

        timestamp::fast_forward_seconds(10);
        withdraw<FakeMoney>(0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        assert!(_stream.last_withdraw_time == 10040, 0);
        assert!(coin::balance<FakeMoney>(recipient) == beforeWithdraw + 60000/5 * 4, 0);

        timestamp::fast_forward_seconds(10);
        withdraw<FakeMoney>(0);
        debug::print(&coin::balance<FakeMoney>(recipient));
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        assert!(_stream.last_withdraw_time == 10050, 0);
        assert!(coin::balance<FakeMoney>(recipient) == beforeWithdraw + 60000/5 * 5, 0);
    }

    #[test_only]
    public fun fee_point<CoinType>(): u8 acquires GlobalConfig {
        assert!(
            exists<GlobalConfig>(@MoveflowCross), error::not_found(STREAM_NOT_PUBLISHED),
        );
        let global = borrow_global<GlobalConfig>(@MoveflowCross);

        let coin_type = type_info::type_name<CoinType>();
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );
        table::borrow(&global.coin_configs, coin_type).fee_point
    }

    #[test_only]
    public fun coin_type<CoinType>(): String acquires GlobalConfig {
        assert!(
            exists<GlobalConfig>(@MoveflowCross), error::not_found(STREAM_NOT_PUBLISHED),
        );
        let global = borrow_global<GlobalConfig>(@MoveflowCross);

        let coin_type = type_info::type_name<CoinType>();
        assert!(
            table::contains(&global.coin_configs, coin_type), error::not_found(COIN_CONF_NOT_FOUND),
        );
        table::borrow(&global.coin_configs, coin_type).coin_type
    }

    #[test(account = @0x1, owner= @MoveflowCross, admin = @0x2, account2 = @0x3, account3 = @0x4)]
    fun batch_create_test(
        account: signer,
        owner: signer,
        admin: signer,
        account2: signer,
        account3: signer
    ) acquires GlobalConfig, Escrow {
        timestamp::set_time_has_started_for_testing(&account);

        let owner_addr = signer::address_of(&owner);
        account::create_account_for_test(owner_addr);
        debug::print(&owner_addr);
        let admin_addr = signer::address_of(&admin);
        account::create_account_for_test(admin_addr);
        debug::print(&admin_addr);
        let account_addr = signer::address_of(&account);
        account::create_account_for_test(account_addr);
        debug::print(&account_addr);
        let account2_addr = signer::address_of(&account2);
        account::create_account_for_test(account2_addr);
        debug::print(&account2_addr);
        let account3_addr = signer::address_of(&account3);
        account::create_account_for_test(account3_addr);
        debug::print(&account3_addr);

        let name = b"Fake money";
        let symbol = b"FMD";

        managed_coin::initialize<FakeMoney>(&owner, name, symbol, 8, false);
        managed_coin::register<FakeMoney>(&account);
        managed_coin::register<FakeMoney>(&account2);
        managed_coin::register<FakeMoney>(&account3);
        managed_coin::register<FakeMoney>(&admin);
        managed_coin::register<FakeMoney>(&owner);
        managed_coin::mint<FakeMoney>(&owner, admin_addr, 100000);
        assert!(coin::balance<FakeMoney>(admin_addr) == 100000, 0);

        //initialize
        assert!(!exists<GlobalConfig>(@MoveflowCross), 1);
        initialize(&owner, owner_addr, admin_addr);
        assert!(exists<GlobalConfig>(@MoveflowCross), 2);

        //register
        register_coin<FakeMoney>(&admin);
        assert!(!exists<Escrow<FakeMoney>>(admin_addr), 3);
        assert!(coin_type<FakeMoney>() == type_info::type_name<FakeMoney>(), 4);
        assert!(fee_point<FakeMoney>() == INIT_FEE_POINT, 5);

        let recipients = vector::empty<address>();
        vector::push_back(&mut recipients, account_addr);
        vector::push_back(&mut recipients, account2_addr);
        vector::push_back(&mut recipients, account3_addr);

        let deposit_amounts = vector::empty<u64>();
        vector::push_back(&mut deposit_amounts, 10000);
        vector::push_back(&mut deposit_amounts, 20000);
        vector::push_back(&mut deposit_amounts, 30000);


        //create
        batchCreate<FakeMoney>(
            &admin,
            utf8(b"test"),
            utf8(b"test"),
            recipients,
            deposit_amounts,
            10000,
            10050,
            10,
            true,
            true,
            true
        );
        assert!(coin::balance<FakeMoney>(admin_addr) == 40000, 0);
        // get _config
        let global = borrow_global_mut<GlobalConfig>(@MoveflowCross);
        let _config = table::borrow(&global.coin_configs, type_info::type_name<FakeMoney>());

        //account
        let _stream = table_with_length::borrow(&global.streams_store, 0);
        debug::print(&coin::balance<FakeMoney>(owner_addr));
        let escrow_coin = borrow_global<Escrow<FakeMoney>>(_stream.escrow_address);
        debug::print(&coin::value(&escrow_coin.coin));
        assert!(_stream.recipient == account_addr, 0);
        assert!(_stream.sender == admin_addr, 0);
        assert!(_stream.start_time == 10000, 0);
        assert!(_stream.stop_time == 10050, 0);
        assert!(_stream.deposit_amount == 10000, 0);
        assert!(_stream.remaining_amount == coin::value(&escrow_coin.coin), 0);
        debug::print(&_stream.rate_per_interval);
        debug::print(&(_stream.deposit_amount * 1000/(_stream.stop_time - _stream.start_time)));
        assert!(_stream.rate_per_interval ==
            _stream.deposit_amount * 1000/((_stream.stop_time - _stream.start_time)/_stream.interval), 0);
        assert!(_stream.last_withdraw_time == 10000, 0);

        //account2
        let _stream = table_with_length::borrow(&global.streams_store, 1);
        debug::print(&coin::balance<FakeMoney>(owner_addr));
        let escrow_coin = borrow_global<Escrow<FakeMoney>>(_stream.escrow_address);
        debug::print(&coin::value(&escrow_coin.coin));
        assert!(_stream.recipient == account2_addr, 0);
        assert!(_stream.sender == admin_addr, 0);
        assert!(_stream.start_time == 10000, 0);
        assert!(_stream.stop_time == 10050, 0);
        assert!(_stream.deposit_amount == 20000, 0);
        assert!(_stream.remaining_amount == coin::value(&escrow_coin.coin), 0);
        debug::print(&_stream.rate_per_interval);
        debug::print(&(_stream.deposit_amount * 1000/(_stream.stop_time - _stream.start_time)));
        assert!(_stream.rate_per_interval ==
            _stream.deposit_amount * 1000/((_stream.stop_time - _stream.start_time)/_stream.interval), 0);
        assert!(_stream.last_withdraw_time == 10000, 0);

        //account3
        let _stream = table_with_length::borrow(&global.streams_store, 2);
        debug::print(&coin::balance<FakeMoney>(owner_addr));
        let escrow_coin = borrow_global<Escrow<FakeMoney>>(_stream.escrow_address);
        debug::print(&coin::value(&escrow_coin.coin));
        assert!(_stream.recipient == account3_addr, 0);
        assert!(_stream.sender == admin_addr, 0);
        assert!(_stream.start_time == 10000, 0);
        assert!(_stream.stop_time == 10050, 0);
        assert!(_stream.deposit_amount == 30000, 0);
        assert!(_stream.remaining_amount == coin::value(&escrow_coin.coin), 0);
        debug::print(&_stream.rate_per_interval);
        debug::print(&(_stream.deposit_amount * 1000/(_stream.stop_time - _stream.start_time)));
        assert!(_stream.rate_per_interval ==
            _stream.deposit_amount * 1000/((_stream.stop_time - _stream.start_time)/_stream.interval), 0);
        assert!(_stream.last_withdraw_time == 10000, 0);
    }
}
