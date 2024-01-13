module MoveflowCross::mfserde {
    use std::vector;
    use std::error;

    const EINVALID_LENGTH: u64 = 0x21;

    public fun serialize_u8(buf: &mut vector<u8>, v: u8) {
        vector::push_back(buf, v);
    }

    public fun serialize_u64(buf: &mut vector<u8>, v: u64) {
        serialize_u8(buf, (((v >> 56) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 48) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 40) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 32) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 24) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 16) & 0xFF) as u8));
        serialize_u8(buf, (((v >> 8) & 0xFF) as u8));
        serialize_u8(buf, ((v & 0xFF) as u8));
    }

    public fun serialize_u64_32byte(buf: &mut vector<u8>, v: u64) {
        let u64_byte = vector::empty<u8>();
        let u64_32byte = vector::empty<u8>();
        serialize_u64(&mut u64_byte, v);
        serialize_vector_32byte(&mut u64_32byte, u64_byte);
        vector::append(buf, u64_32byte);
    }

    public fun serialize_vector_32byte(buf: &mut vector<u8>, v: vector<u8>) {
        let v_len = vector::length(&v);
        assert!(v_len <= 32, error::invalid_argument(EINVALID_LENGTH));
        let vec_32byte = vector::empty<u8>();
        while ((vector::length(&vec_32byte) + v_len) < 32) {
            serialize_u8(&mut vec_32byte, 0);
        };
        vector::append(&mut vec_32byte, v);
        assert!(vector::length(&vec_32byte) == 32, error::invalid_state(EINVALID_LENGTH));
        vector::append(buf, vec_32byte);
    }

    #[test_only]
    use aptos_std::debug;

    #[test]
    fun test_serialize() {
        let data = vector::empty<u8>();
        serialize_u8(&mut data, 1);
        assert!(data == vector<u8>[1], 0);

        let test_vec = vector<u8>[168, 196, 170, 228, 206, 117,
                                    144, 114, 217,  51, 189,  74,
                                    81,  23,  34,  87,  98,  46,
                                    241,  40
                                ];
        let data1 = vector::empty<u8>();
        serialize_vector_32byte(&mut data1, test_vec);
        debug::print(&data1);
        assert!(vector::length(&data1) == 32, 0);

        let payload = vector::empty<u8>();
        serialize_u64_32byte(&mut payload, (1 as u64));
        serialize_vector_32byte(&mut payload, test_vec);
        serialize_vector_32byte(&mut payload, test_vec);
        serialize_u64_32byte(&mut payload, (1234 as u64));
        debug::print(&payload);
        assert!(vector::length(&payload) == 128, 0);

        let data = vector::empty<u8>();
        serialize_u64_32byte(&mut data, 72623859790382856);
        let vec_32byte = vector::empty<u8>();
        let i = 0;
        loop {
            if (i >= 24) break;
            serialize_u8(&mut vec_32byte, 0);
            i = i + 1;
        };
        vector::append(&mut vec_32byte, vector<u8>[1, 2, 3, 4, 5, 6, 7, 8]);
        debug::print(&data);
        debug::print(&vec_32byte);
        assert!(data == vec_32byte, 0);
    }
}