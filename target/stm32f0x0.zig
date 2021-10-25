pub fn Register(comptime R: type) type {
    return RegisterRW(R, R);
}

pub fn RegisterRW(comptime Read: type, comptime Write: type) type {
    return struct {
        raw_ptr: *volatile u32,

        const Self = @This();

        pub fn init(address: usize) Self {
            return Self{ .raw_ptr = @intToPtr(*volatile u32, address) };
        }

        pub fn initRange(address: usize, comptime dim_increment: usize, comptime num_registers: usize) [num_registers]Self {
            var registers: [num_registers]Self = undefined;
            var i: usize = 0;
            while (i < num_registers) : (i += 1) {
                registers[i] = Self.init(address + (i * dim_increment));
            }
            return registers;
        }

        pub fn read(self: Self) Read {
            return @bitCast(Read, self.raw_ptr.*);
        }

        pub fn write(self: Self, value: Write) void {
            self.raw_ptr.* = @bitCast(u32, value);
        }

        pub fn modify(self: Self, new_value: anytype) void {
            if (Read != Write) {
                @compileError("Can't modify because read and write types for this register aren't the same.");
            }
            var old_value = self.read();
            const info = @typeInfo(@TypeOf(new_value));
            inline for (info.Struct.fields) |field| {
                @field(old_value, field.name) = @field(new_value, field.name);
            }
            self.write(old_value);
        }

        pub fn read_raw(self: Self) u32 {
            return self.raw_ptr.*;
        }

        pub fn write_raw(self: Self, value: u32) void {
            self.raw_ptr.* = value;
        }

        pub fn default_read_value(self: Self) Read {
            return Read{};
        }

        pub fn default_write_value(self: Self) Write {
            return Write{};
        }
    };
}

pub fn RepeatedFields(comptime num_fields: usize, comptime field_name: []const u8, comptime T: type) type {
    var info = @typeInfo(packed struct { f: T });
    var fields: [num_fields]std.builtin.TypeInfo.StructField = undefined;
    var field_ix: usize = 0;
    while (field_ix < num_fields) : (field_ix += 1) {
        var field = info.Struct.fields[0];

        // awkward workaround for lack of comptime allocator
        @setEvalBranchQuota(100000);
        var field_ix_buffer: [field_name.len + 16]u8 = undefined;
        var stream = std.io.FixedBufferStream([]u8){ .buffer = &field_ix_buffer, .pos = 0 };
        std.fmt.format(stream.writer(), "{}{}", .{ field_name, field_ix }) catch unreachable;
        field.name = stream.getWritten();

        field.default_value = T.default_value;

        fields[field_ix] = field;
    }

    // TODO this might not be safe to set
    info.Struct.is_tuple = true;

    info.Struct.fields = &fields;
    return @Type(info);
}

///cyclic redundancy check calculation
///unit
pub const crc = struct {

    //////////////////////////
    ///DR
    const dr_val = packed struct {
        ///DR [0:31]
        ///Data register bits
        dr: u32 = 4294967295,
    };
    ///Data register
    pub const dr = Register(dr_val).init(0x40023000 + 0x0);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR [0:7]
        ///General-purpose 8-bit data register
        ///bits
        idr: u8 = 0,
        _unused8: u24 = 0,
    };
    ///Independent data register
    pub const idr = Register(idr_val).init(0x40023000 + 0x4);

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        ///RESET [0:0]
        ///reset bit
        reset: u1 = 0,
        _unused1: u2 = 0,
        ///POLYSIZE [3:4]
        ///Polynomial size
        polysize: packed enum(u2) {
            ///32-bit polynomial
            polysize32 = 0,
            ///16-bit polynomial
            polysize16 = 1,
            ///8-bit polynomial
            polysize8 = 2,
            ///7-bit polynomial
            polysize7 = 3,
        } = .polysize32,
        ///REV_IN [5:6]
        ///Reverse input data
        rev_in: packed enum(u2) {
            ///Bit order not affected
            normal = 0,
            ///Bit reversal done by byte
            byte = 1,
            ///Bit reversal done by half-word
            half_word = 2,
            ///Bit reversal done by word
            word = 3,
        } = .normal,
        ///REV_OUT [7:7]
        ///Reverse output data
        rev_out: packed enum(u1) {
            ///Bit order not affected
            normal = 0,
            ///Bit reversed output
            reversed = 1,
        } = .normal,
        _unused8: u24 = 0,
    };
    ///Control register
    pub const cr = Register(cr_val).init(0x40023000 + 0x8);

    //////////////////////////
    ///INIT
    const init_val = packed struct {
        ///INIT [0:31]
        ///Programmable initial CRC
        ///value
        init: u32 = 4294967295,
    };
    ///Initial CRC value
    pub const init = Register(init_val).init(0x40023000 + 0x10);

    //////////////////////////
    ///DR8
    const dr8_val = packed struct {
        ///DR8 [0:7]
        ///Data register bits
        dr8: u8 = 85,
        _unused8: u24 = 0,
    };
    ///Data register - byte sized
    pub const dr8 = Register(dr8_val).init(0x40023000 + 0);

    //////////////////////////
    ///DR16
    const dr16_val = packed struct {
        ///DR16 [0:15]
        ///Data register bits
        dr16: u16 = 21813,
        _unused16: u16 = 0,
    };
    ///Data register - half-word sized
    pub const dr16 = Register(dr16_val).init(0x40023000 + 0);
};

///General-purpose I/Os
pub const gpiof = struct {

    //////////////////////////
    ///MODER
    const moder_val = packed struct {
        ///MODER0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        moder0: u2 = 0,
        ///MODER1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        moder1: u2 = 0,
        ///MODER2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        moder2: u2 = 0,
        ///MODER3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        moder3: u2 = 0,
        ///MODER4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        moder4: u2 = 0,
        ///MODER5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        moder5: u2 = 0,
        ///MODER6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        moder6: u2 = 0,
        ///MODER7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        moder7: u2 = 0,
        ///MODER8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        moder8: u2 = 0,
        ///MODER9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        moder9: u2 = 0,
        ///MODER10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        moder10: u2 = 0,
        ///MODER11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        moder11: u2 = 0,
        ///MODER12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        moder12: u2 = 0,
        ///MODER13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        moder13: u2 = 0,
        ///MODER14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        moder14: u2 = 0,
        ///MODER15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        moder15: packed enum(u2) {
            ///Input mode (reset state)
            input = 0,
            ///General purpose output mode
            output = 1,
            ///Alternate function mode
            alternate = 2,
            ///Analog mode
            analog = 3,
        } = .input,
    };
    ///GPIO port mode register
    pub const moder = Register(moder_val).init(0x48001400 + 0x0);

    //////////////////////////
    ///OTYPER
    const otyper_val = packed struct {
        ///OT0 [0:0]
        ///Port x configuration bit 0
        ot0: u1 = 0,
        ///OT1 [1:1]
        ///Port x configuration bit 1
        ot1: u1 = 0,
        ///OT2 [2:2]
        ///Port x configuration bit 2
        ot2: u1 = 0,
        ///OT3 [3:3]
        ///Port x configuration bit 3
        ot3: u1 = 0,
        ///OT4 [4:4]
        ///Port x configuration bit 4
        ot4: u1 = 0,
        ///OT5 [5:5]
        ///Port x configuration bit 5
        ot5: u1 = 0,
        ///OT6 [6:6]
        ///Port x configuration bit 6
        ot6: u1 = 0,
        ///OT7 [7:7]
        ///Port x configuration bit 7
        ot7: u1 = 0,
        ///OT8 [8:8]
        ///Port x configuration bit 8
        ot8: u1 = 0,
        ///OT9 [9:9]
        ///Port x configuration bit 9
        ot9: u1 = 0,
        ///OT10 [10:10]
        ///Port x configuration bit
        ///10
        ot10: u1 = 0,
        ///OT11 [11:11]
        ///Port x configuration bit
        ///11
        ot11: u1 = 0,
        ///OT12 [12:12]
        ///Port x configuration bit
        ///12
        ot12: u1 = 0,
        ///OT13 [13:13]
        ///Port x configuration bit
        ///13
        ot13: u1 = 0,
        ///OT14 [14:14]
        ///Port x configuration bit
        ///14
        ot14: u1 = 0,
        ///OT15 [15:15]
        ///Port x configuration bit
        ///15
        ot15: packed enum(u1) {
            ///Output push-pull (reset state)
            push_pull = 0,
            ///Output open-drain
            open_drain = 1,
        } = .push_pull,
        _unused16: u16 = 0,
    };
    ///GPIO port output type register
    pub const otyper = Register(otyper_val).init(0x48001400 + 0x4);

    //////////////////////////
    ///OSPEEDR
    const ospeedr_val = packed struct {
        ///OSPEEDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr0: u2 = 0,
        ///OSPEEDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr1: u2 = 0,
        ///OSPEEDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr2: u2 = 0,
        ///OSPEEDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr3: u2 = 0,
        ///OSPEEDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr4: u2 = 0,
        ///OSPEEDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr5: u2 = 0,
        ///OSPEEDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr6: u2 = 0,
        ///OSPEEDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr7: u2 = 0,
        ///OSPEEDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr8: u2 = 0,
        ///OSPEEDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr9: u2 = 0,
        ///OSPEEDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr10: u2 = 0,
        ///OSPEEDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr11: u2 = 0,
        ///OSPEEDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr12: u2 = 0,
        ///OSPEEDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr13: u2 = 0,
        ///OSPEEDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr14: u2 = 0,
        ///OSPEEDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr15: packed enum(u2) {
            ///Low speed
            low_speed = 0,
            ///Medium speed
            medium_speed = 1,
            ///High speed
            high_speed = 2,
            ///Very high speed
            very_high_speed = 3,
        } = .low_speed,
    };
    ///GPIO port output speed
    ///register
    pub const ospeedr = Register(ospeedr_val).init(0x48001400 + 0x8);

    //////////////////////////
    ///PUPDR
    const pupdr_val = packed struct {
        ///PUPDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr0: u2 = 0,
        ///PUPDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr1: u2 = 0,
        ///PUPDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr2: u2 = 0,
        ///PUPDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr3: u2 = 0,
        ///PUPDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr4: u2 = 0,
        ///PUPDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr5: u2 = 0,
        ///PUPDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr6: u2 = 0,
        ///PUPDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr7: u2 = 0,
        ///PUPDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr8: u2 = 0,
        ///PUPDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr9: u2 = 0,
        ///PUPDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr10: u2 = 0,
        ///PUPDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr11: u2 = 0,
        ///PUPDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr12: u2 = 0,
        ///PUPDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr13: u2 = 0,
        ///PUPDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr14: u2 = 0,
        ///PUPDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr15: packed enum(u2) {
            ///No pull-up, pull-down
            floating = 0,
            ///Pull-up
            pull_up = 1,
            ///Pull-down
            pull_down = 2,
        } = .floating,
    };
    ///GPIO port pull-up/pull-down
    ///register
    pub const pupdr = Register(pupdr_val).init(0x48001400 + 0xC);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR0 [0:0]
        ///Port input data (y =
        ///0..15)
        idr0: u1 = 0,
        ///IDR1 [1:1]
        ///Port input data (y =
        ///0..15)
        idr1: u1 = 0,
        ///IDR2 [2:2]
        ///Port input data (y =
        ///0..15)
        idr2: u1 = 0,
        ///IDR3 [3:3]
        ///Port input data (y =
        ///0..15)
        idr3: u1 = 0,
        ///IDR4 [4:4]
        ///Port input data (y =
        ///0..15)
        idr4: u1 = 0,
        ///IDR5 [5:5]
        ///Port input data (y =
        ///0..15)
        idr5: u1 = 0,
        ///IDR6 [6:6]
        ///Port input data (y =
        ///0..15)
        idr6: u1 = 0,
        ///IDR7 [7:7]
        ///Port input data (y =
        ///0..15)
        idr7: u1 = 0,
        ///IDR8 [8:8]
        ///Port input data (y =
        ///0..15)
        idr8: u1 = 0,
        ///IDR9 [9:9]
        ///Port input data (y =
        ///0..15)
        idr9: u1 = 0,
        ///IDR10 [10:10]
        ///Port input data (y =
        ///0..15)
        idr10: u1 = 0,
        ///IDR11 [11:11]
        ///Port input data (y =
        ///0..15)
        idr11: u1 = 0,
        ///IDR12 [12:12]
        ///Port input data (y =
        ///0..15)
        idr12: u1 = 0,
        ///IDR13 [13:13]
        ///Port input data (y =
        ///0..15)
        idr13: u1 = 0,
        ///IDR14 [14:14]
        ///Port input data (y =
        ///0..15)
        idr14: u1 = 0,
        ///IDR15 [15:15]
        ///Port input data (y =
        ///0..15)
        idr15: packed enum(u1) {
            ///Input is logic high
            high = 1,
            ///Input is logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port input data register
    pub const idr = RegisterRW(idr_val, void).init(0x48001400 + 0x10);

    //////////////////////////
    ///ODR
    const odr_val = packed struct {
        ///ODR0 [0:0]
        ///Port output data (y =
        ///0..15)
        odr0: u1 = 0,
        ///ODR1 [1:1]
        ///Port output data (y =
        ///0..15)
        odr1: u1 = 0,
        ///ODR2 [2:2]
        ///Port output data (y =
        ///0..15)
        odr2: u1 = 0,
        ///ODR3 [3:3]
        ///Port output data (y =
        ///0..15)
        odr3: u1 = 0,
        ///ODR4 [4:4]
        ///Port output data (y =
        ///0..15)
        odr4: u1 = 0,
        ///ODR5 [5:5]
        ///Port output data (y =
        ///0..15)
        odr5: u1 = 0,
        ///ODR6 [6:6]
        ///Port output data (y =
        ///0..15)
        odr6: u1 = 0,
        ///ODR7 [7:7]
        ///Port output data (y =
        ///0..15)
        odr7: u1 = 0,
        ///ODR8 [8:8]
        ///Port output data (y =
        ///0..15)
        odr8: u1 = 0,
        ///ODR9 [9:9]
        ///Port output data (y =
        ///0..15)
        odr9: u1 = 0,
        ///ODR10 [10:10]
        ///Port output data (y =
        ///0..15)
        odr10: u1 = 0,
        ///ODR11 [11:11]
        ///Port output data (y =
        ///0..15)
        odr11: u1 = 0,
        ///ODR12 [12:12]
        ///Port output data (y =
        ///0..15)
        odr12: u1 = 0,
        ///ODR13 [13:13]
        ///Port output data (y =
        ///0..15)
        odr13: u1 = 0,
        ///ODR14 [14:14]
        ///Port output data (y =
        ///0..15)
        odr14: u1 = 0,
        ///ODR15 [15:15]
        ///Port output data (y =
        ///0..15)
        odr15: packed enum(u1) {
            ///Set output to logic high
            high = 1,
            ///Set output to logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port output data register
    pub const odr = Register(odr_val).init(0x48001400 + 0x14);

    //////////////////////////
    ///BSRR
    const bsrr_val = packed struct {
        ///BS0 [0:0]
        ///Port x set bit y (y=
        ///0..15)
        bs0: u1 = 0,
        ///BS1 [1:1]
        ///Port x set bit y (y=
        ///0..15)
        bs1: u1 = 0,
        ///BS2 [2:2]
        ///Port x set bit y (y=
        ///0..15)
        bs2: u1 = 0,
        ///BS3 [3:3]
        ///Port x set bit y (y=
        ///0..15)
        bs3: u1 = 0,
        ///BS4 [4:4]
        ///Port x set bit y (y=
        ///0..15)
        bs4: u1 = 0,
        ///BS5 [5:5]
        ///Port x set bit y (y=
        ///0..15)
        bs5: u1 = 0,
        ///BS6 [6:6]
        ///Port x set bit y (y=
        ///0..15)
        bs6: u1 = 0,
        ///BS7 [7:7]
        ///Port x set bit y (y=
        ///0..15)
        bs7: u1 = 0,
        ///BS8 [8:8]
        ///Port x set bit y (y=
        ///0..15)
        bs8: u1 = 0,
        ///BS9 [9:9]
        ///Port x set bit y (y=
        ///0..15)
        bs9: u1 = 0,
        ///BS10 [10:10]
        ///Port x set bit y (y=
        ///0..15)
        bs10: u1 = 0,
        ///BS11 [11:11]
        ///Port x set bit y (y=
        ///0..15)
        bs11: u1 = 0,
        ///BS12 [12:12]
        ///Port x set bit y (y=
        ///0..15)
        bs12: u1 = 0,
        ///BS13 [13:13]
        ///Port x set bit y (y=
        ///0..15)
        bs13: u1 = 0,
        ///BS14 [14:14]
        ///Port x set bit y (y=
        ///0..15)
        bs14: u1 = 0,
        ///BS15 [15:15]
        ///Port x set bit y (y=
        ///0..15)
        bs15: u1 = 0,
        ///BR0 [16:16]
        ///Port x set bit y (y=
        ///0..15)
        br0: u1 = 0,
        ///BR1 [17:17]
        ///Port x reset bit y (y =
        ///0..15)
        br1: u1 = 0,
        ///BR2 [18:18]
        ///Port x reset bit y (y =
        ///0..15)
        br2: u1 = 0,
        ///BR3 [19:19]
        ///Port x reset bit y (y =
        ///0..15)
        br3: u1 = 0,
        ///BR4 [20:20]
        ///Port x reset bit y (y =
        ///0..15)
        br4: u1 = 0,
        ///BR5 [21:21]
        ///Port x reset bit y (y =
        ///0..15)
        br5: u1 = 0,
        ///BR6 [22:22]
        ///Port x reset bit y (y =
        ///0..15)
        br6: u1 = 0,
        ///BR7 [23:23]
        ///Port x reset bit y (y =
        ///0..15)
        br7: u1 = 0,
        ///BR8 [24:24]
        ///Port x reset bit y (y =
        ///0..15)
        br8: u1 = 0,
        ///BR9 [25:25]
        ///Port x reset bit y (y =
        ///0..15)
        br9: u1 = 0,
        ///BR10 [26:26]
        ///Port x reset bit y (y =
        ///0..15)
        br10: u1 = 0,
        ///BR11 [27:27]
        ///Port x reset bit y (y =
        ///0..15)
        br11: u1 = 0,
        ///BR12 [28:28]
        ///Port x reset bit y (y =
        ///0..15)
        br12: u1 = 0,
        ///BR13 [29:29]
        ///Port x reset bit y (y =
        ///0..15)
        br13: u1 = 0,
        ///BR14 [30:30]
        ///Port x reset bit y (y =
        ///0..15)
        br14: u1 = 0,
        ///BR15 [31:31]
        ///Port x reset bit y (y =
        ///0..15)
        br15: u1 = 0,
    };
    ///GPIO port bit set/reset
    ///register
    pub const bsrr = RegisterRW(void, bsrr_val).init(0x48001400 + 0x18);

    //////////////////////////
    ///LCKR
    const lckr_val = packed struct {
        ///LCK0 [0:0]
        ///Port x lock bit y (y=
        ///0..15)
        lck0: u1 = 0,
        ///LCK1 [1:1]
        ///Port x lock bit y (y=
        ///0..15)
        lck1: u1 = 0,
        ///LCK2 [2:2]
        ///Port x lock bit y (y=
        ///0..15)
        lck2: u1 = 0,
        ///LCK3 [3:3]
        ///Port x lock bit y (y=
        ///0..15)
        lck3: u1 = 0,
        ///LCK4 [4:4]
        ///Port x lock bit y (y=
        ///0..15)
        lck4: u1 = 0,
        ///LCK5 [5:5]
        ///Port x lock bit y (y=
        ///0..15)
        lck5: u1 = 0,
        ///LCK6 [6:6]
        ///Port x lock bit y (y=
        ///0..15)
        lck6: u1 = 0,
        ///LCK7 [7:7]
        ///Port x lock bit y (y=
        ///0..15)
        lck7: u1 = 0,
        ///LCK8 [8:8]
        ///Port x lock bit y (y=
        ///0..15)
        lck8: u1 = 0,
        ///LCK9 [9:9]
        ///Port x lock bit y (y=
        ///0..15)
        lck9: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCK10 [10:10]
        ///Port x lock bit y (y=
        ///0..15)
        lck10: u1 = 0,
        ///LCK11 [11:11]
        ///Port x lock bit y (y=
        ///0..15)
        lck11: u1 = 0,
        ///LCK12 [12:12]
        ///Port x lock bit y (y=
        ///0..15)
        lck12: u1 = 0,
        ///LCK13 [13:13]
        ///Port x lock bit y (y=
        ///0..15)
        lck13: u1 = 0,
        ///LCK14 [14:14]
        ///Port x lock bit y (y=
        ///0..15)
        lck14: u1 = 0,
        ///LCK15 [15:15]
        ///Port x lock bit y (y=
        ///0..15)
        lck15: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCKK [16:16]
        ///Port x lock bit y
        lckk: packed enum(u1) {
            ///Port configuration lock key not active
            not_active = 0,
            ///Port configuration lock key active
            active = 1,
        } = .not_active,
        _unused17: u15 = 0,
    };
    ///GPIO port configuration lock
    ///register
    pub const lckr = Register(lckr_val).init(0x48001400 + 0x1C);

    //////////////////////////
    ///AFRL
    const afrl_val = packed struct {
        ///AFRL0 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl0: u4 = 0,
        ///AFRL1 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl1: u4 = 0,
        ///AFRL2 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl2: u4 = 0,
        ///AFRL3 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl3: u4 = 0,
        ///AFRL4 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl4: u4 = 0,
        ///AFRL5 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl5: u4 = 0,
        ///AFRL6 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl6: u4 = 0,
        ///AFRL7 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl7: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function low
    ///register
    pub const afrl = Register(afrl_val).init(0x48001400 + 0x20);

    //////////////////////////
    ///AFRH
    const afrh_val = packed struct {
        ///AFRH8 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh8: u4 = 0,
        ///AFRH9 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh9: u4 = 0,
        ///AFRH10 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh10: u4 = 0,
        ///AFRH11 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh11: u4 = 0,
        ///AFRH12 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh12: u4 = 0,
        ///AFRH13 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh13: u4 = 0,
        ///AFRH14 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh14: u4 = 0,
        ///AFRH15 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh15: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function high
    ///register
    pub const afrh = Register(afrh_val).init(0x48001400 + 0x24);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BR0 [0:0]
        ///Port x Reset bit y
        br0: u1 = 0,
        ///BR1 [1:1]
        ///Port x Reset bit y
        br1: u1 = 0,
        ///BR2 [2:2]
        ///Port x Reset bit y
        br2: u1 = 0,
        ///BR3 [3:3]
        ///Port x Reset bit y
        br3: u1 = 0,
        ///BR4 [4:4]
        ///Port x Reset bit y
        br4: u1 = 0,
        ///BR5 [5:5]
        ///Port x Reset bit y
        br5: u1 = 0,
        ///BR6 [6:6]
        ///Port x Reset bit y
        br6: u1 = 0,
        ///BR7 [7:7]
        ///Port x Reset bit y
        br7: u1 = 0,
        ///BR8 [8:8]
        ///Port x Reset bit y
        br8: u1 = 0,
        ///BR9 [9:9]
        ///Port x Reset bit y
        br9: u1 = 0,
        ///BR10 [10:10]
        ///Port x Reset bit y
        br10: u1 = 0,
        ///BR11 [11:11]
        ///Port x Reset bit y
        br11: u1 = 0,
        ///BR12 [12:12]
        ///Port x Reset bit y
        br12: u1 = 0,
        ///BR13 [13:13]
        ///Port x Reset bit y
        br13: u1 = 0,
        ///BR14 [14:14]
        ///Port x Reset bit y
        br14: u1 = 0,
        ///BR15 [15:15]
        ///Port x Reset bit y
        br15: u1 = 0,
        _unused16: u16 = 0,
    };
    ///Port bit reset register
    pub const brr = RegisterRW(void, brr_val).init(0x48001400 + 0x28);
};

///General-purpose I/Os
pub const gpiod = struct {

    //////////////////////////
    ///MODER
    const moder_val = packed struct {
        ///MODER0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        moder0: u2 = 0,
        ///MODER1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        moder1: u2 = 0,
        ///MODER2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        moder2: u2 = 0,
        ///MODER3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        moder3: u2 = 0,
        ///MODER4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        moder4: u2 = 0,
        ///MODER5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        moder5: u2 = 0,
        ///MODER6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        moder6: u2 = 0,
        ///MODER7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        moder7: u2 = 0,
        ///MODER8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        moder8: u2 = 0,
        ///MODER9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        moder9: u2 = 0,
        ///MODER10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        moder10: u2 = 0,
        ///MODER11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        moder11: u2 = 0,
        ///MODER12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        moder12: u2 = 0,
        ///MODER13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        moder13: u2 = 0,
        ///MODER14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        moder14: u2 = 0,
        ///MODER15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        moder15: packed enum(u2) {
            ///Input mode (reset state)
            input = 0,
            ///General purpose output mode
            output = 1,
            ///Alternate function mode
            alternate = 2,
            ///Analog mode
            analog = 3,
        } = .input,
    };
    ///GPIO port mode register
    pub const moder = Register(moder_val).init(0x48000C00 + 0x0);

    //////////////////////////
    ///OTYPER
    const otyper_val = packed struct {
        ///OT0 [0:0]
        ///Port x configuration bit 0
        ot0: u1 = 0,
        ///OT1 [1:1]
        ///Port x configuration bit 1
        ot1: u1 = 0,
        ///OT2 [2:2]
        ///Port x configuration bit 2
        ot2: u1 = 0,
        ///OT3 [3:3]
        ///Port x configuration bit 3
        ot3: u1 = 0,
        ///OT4 [4:4]
        ///Port x configuration bit 4
        ot4: u1 = 0,
        ///OT5 [5:5]
        ///Port x configuration bit 5
        ot5: u1 = 0,
        ///OT6 [6:6]
        ///Port x configuration bit 6
        ot6: u1 = 0,
        ///OT7 [7:7]
        ///Port x configuration bit 7
        ot7: u1 = 0,
        ///OT8 [8:8]
        ///Port x configuration bit 8
        ot8: u1 = 0,
        ///OT9 [9:9]
        ///Port x configuration bit 9
        ot9: u1 = 0,
        ///OT10 [10:10]
        ///Port x configuration bit
        ///10
        ot10: u1 = 0,
        ///OT11 [11:11]
        ///Port x configuration bit
        ///11
        ot11: u1 = 0,
        ///OT12 [12:12]
        ///Port x configuration bit
        ///12
        ot12: u1 = 0,
        ///OT13 [13:13]
        ///Port x configuration bit
        ///13
        ot13: u1 = 0,
        ///OT14 [14:14]
        ///Port x configuration bit
        ///14
        ot14: u1 = 0,
        ///OT15 [15:15]
        ///Port x configuration bit
        ///15
        ot15: packed enum(u1) {
            ///Output push-pull (reset state)
            push_pull = 0,
            ///Output open-drain
            open_drain = 1,
        } = .push_pull,
        _unused16: u16 = 0,
    };
    ///GPIO port output type register
    pub const otyper = Register(otyper_val).init(0x48000C00 + 0x4);

    //////////////////////////
    ///OSPEEDR
    const ospeedr_val = packed struct {
        ///OSPEEDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr0: u2 = 0,
        ///OSPEEDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr1: u2 = 0,
        ///OSPEEDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr2: u2 = 0,
        ///OSPEEDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr3: u2 = 0,
        ///OSPEEDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr4: u2 = 0,
        ///OSPEEDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr5: u2 = 0,
        ///OSPEEDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr6: u2 = 0,
        ///OSPEEDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr7: u2 = 0,
        ///OSPEEDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr8: u2 = 0,
        ///OSPEEDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr9: u2 = 0,
        ///OSPEEDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr10: u2 = 0,
        ///OSPEEDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr11: u2 = 0,
        ///OSPEEDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr12: u2 = 0,
        ///OSPEEDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr13: u2 = 0,
        ///OSPEEDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr14: u2 = 0,
        ///OSPEEDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr15: packed enum(u2) {
            ///Low speed
            low_speed = 0,
            ///Medium speed
            medium_speed = 1,
            ///High speed
            high_speed = 2,
            ///Very high speed
            very_high_speed = 3,
        } = .low_speed,
    };
    ///GPIO port output speed
    ///register
    pub const ospeedr = Register(ospeedr_val).init(0x48000C00 + 0x8);

    //////////////////////////
    ///PUPDR
    const pupdr_val = packed struct {
        ///PUPDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr0: u2 = 0,
        ///PUPDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr1: u2 = 0,
        ///PUPDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr2: u2 = 0,
        ///PUPDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr3: u2 = 0,
        ///PUPDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr4: u2 = 0,
        ///PUPDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr5: u2 = 0,
        ///PUPDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr6: u2 = 0,
        ///PUPDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr7: u2 = 0,
        ///PUPDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr8: u2 = 0,
        ///PUPDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr9: u2 = 0,
        ///PUPDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr10: u2 = 0,
        ///PUPDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr11: u2 = 0,
        ///PUPDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr12: u2 = 0,
        ///PUPDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr13: u2 = 0,
        ///PUPDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr14: u2 = 0,
        ///PUPDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr15: packed enum(u2) {
            ///No pull-up, pull-down
            floating = 0,
            ///Pull-up
            pull_up = 1,
            ///Pull-down
            pull_down = 2,
        } = .floating,
    };
    ///GPIO port pull-up/pull-down
    ///register
    pub const pupdr = Register(pupdr_val).init(0x48000C00 + 0xC);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR0 [0:0]
        ///Port input data (y =
        ///0..15)
        idr0: u1 = 0,
        ///IDR1 [1:1]
        ///Port input data (y =
        ///0..15)
        idr1: u1 = 0,
        ///IDR2 [2:2]
        ///Port input data (y =
        ///0..15)
        idr2: u1 = 0,
        ///IDR3 [3:3]
        ///Port input data (y =
        ///0..15)
        idr3: u1 = 0,
        ///IDR4 [4:4]
        ///Port input data (y =
        ///0..15)
        idr4: u1 = 0,
        ///IDR5 [5:5]
        ///Port input data (y =
        ///0..15)
        idr5: u1 = 0,
        ///IDR6 [6:6]
        ///Port input data (y =
        ///0..15)
        idr6: u1 = 0,
        ///IDR7 [7:7]
        ///Port input data (y =
        ///0..15)
        idr7: u1 = 0,
        ///IDR8 [8:8]
        ///Port input data (y =
        ///0..15)
        idr8: u1 = 0,
        ///IDR9 [9:9]
        ///Port input data (y =
        ///0..15)
        idr9: u1 = 0,
        ///IDR10 [10:10]
        ///Port input data (y =
        ///0..15)
        idr10: u1 = 0,
        ///IDR11 [11:11]
        ///Port input data (y =
        ///0..15)
        idr11: u1 = 0,
        ///IDR12 [12:12]
        ///Port input data (y =
        ///0..15)
        idr12: u1 = 0,
        ///IDR13 [13:13]
        ///Port input data (y =
        ///0..15)
        idr13: u1 = 0,
        ///IDR14 [14:14]
        ///Port input data (y =
        ///0..15)
        idr14: u1 = 0,
        ///IDR15 [15:15]
        ///Port input data (y =
        ///0..15)
        idr15: packed enum(u1) {
            ///Input is logic high
            high = 1,
            ///Input is logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port input data register
    pub const idr = RegisterRW(idr_val, void).init(0x48000C00 + 0x10);

    //////////////////////////
    ///ODR
    const odr_val = packed struct {
        ///ODR0 [0:0]
        ///Port output data (y =
        ///0..15)
        odr0: u1 = 0,
        ///ODR1 [1:1]
        ///Port output data (y =
        ///0..15)
        odr1: u1 = 0,
        ///ODR2 [2:2]
        ///Port output data (y =
        ///0..15)
        odr2: u1 = 0,
        ///ODR3 [3:3]
        ///Port output data (y =
        ///0..15)
        odr3: u1 = 0,
        ///ODR4 [4:4]
        ///Port output data (y =
        ///0..15)
        odr4: u1 = 0,
        ///ODR5 [5:5]
        ///Port output data (y =
        ///0..15)
        odr5: u1 = 0,
        ///ODR6 [6:6]
        ///Port output data (y =
        ///0..15)
        odr6: u1 = 0,
        ///ODR7 [7:7]
        ///Port output data (y =
        ///0..15)
        odr7: u1 = 0,
        ///ODR8 [8:8]
        ///Port output data (y =
        ///0..15)
        odr8: u1 = 0,
        ///ODR9 [9:9]
        ///Port output data (y =
        ///0..15)
        odr9: u1 = 0,
        ///ODR10 [10:10]
        ///Port output data (y =
        ///0..15)
        odr10: u1 = 0,
        ///ODR11 [11:11]
        ///Port output data (y =
        ///0..15)
        odr11: u1 = 0,
        ///ODR12 [12:12]
        ///Port output data (y =
        ///0..15)
        odr12: u1 = 0,
        ///ODR13 [13:13]
        ///Port output data (y =
        ///0..15)
        odr13: u1 = 0,
        ///ODR14 [14:14]
        ///Port output data (y =
        ///0..15)
        odr14: u1 = 0,
        ///ODR15 [15:15]
        ///Port output data (y =
        ///0..15)
        odr15: packed enum(u1) {
            ///Set output to logic high
            high = 1,
            ///Set output to logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port output data register
    pub const odr = Register(odr_val).init(0x48000C00 + 0x14);

    //////////////////////////
    ///BSRR
    const bsrr_val = packed struct {
        ///BS0 [0:0]
        ///Port x set bit y (y=
        ///0..15)
        bs0: u1 = 0,
        ///BS1 [1:1]
        ///Port x set bit y (y=
        ///0..15)
        bs1: u1 = 0,
        ///BS2 [2:2]
        ///Port x set bit y (y=
        ///0..15)
        bs2: u1 = 0,
        ///BS3 [3:3]
        ///Port x set bit y (y=
        ///0..15)
        bs3: u1 = 0,
        ///BS4 [4:4]
        ///Port x set bit y (y=
        ///0..15)
        bs4: u1 = 0,
        ///BS5 [5:5]
        ///Port x set bit y (y=
        ///0..15)
        bs5: u1 = 0,
        ///BS6 [6:6]
        ///Port x set bit y (y=
        ///0..15)
        bs6: u1 = 0,
        ///BS7 [7:7]
        ///Port x set bit y (y=
        ///0..15)
        bs7: u1 = 0,
        ///BS8 [8:8]
        ///Port x set bit y (y=
        ///0..15)
        bs8: u1 = 0,
        ///BS9 [9:9]
        ///Port x set bit y (y=
        ///0..15)
        bs9: u1 = 0,
        ///BS10 [10:10]
        ///Port x set bit y (y=
        ///0..15)
        bs10: u1 = 0,
        ///BS11 [11:11]
        ///Port x set bit y (y=
        ///0..15)
        bs11: u1 = 0,
        ///BS12 [12:12]
        ///Port x set bit y (y=
        ///0..15)
        bs12: u1 = 0,
        ///BS13 [13:13]
        ///Port x set bit y (y=
        ///0..15)
        bs13: u1 = 0,
        ///BS14 [14:14]
        ///Port x set bit y (y=
        ///0..15)
        bs14: u1 = 0,
        ///BS15 [15:15]
        ///Port x set bit y (y=
        ///0..15)
        bs15: u1 = 0,
        ///BR0 [16:16]
        ///Port x set bit y (y=
        ///0..15)
        br0: u1 = 0,
        ///BR1 [17:17]
        ///Port x reset bit y (y =
        ///0..15)
        br1: u1 = 0,
        ///BR2 [18:18]
        ///Port x reset bit y (y =
        ///0..15)
        br2: u1 = 0,
        ///BR3 [19:19]
        ///Port x reset bit y (y =
        ///0..15)
        br3: u1 = 0,
        ///BR4 [20:20]
        ///Port x reset bit y (y =
        ///0..15)
        br4: u1 = 0,
        ///BR5 [21:21]
        ///Port x reset bit y (y =
        ///0..15)
        br5: u1 = 0,
        ///BR6 [22:22]
        ///Port x reset bit y (y =
        ///0..15)
        br6: u1 = 0,
        ///BR7 [23:23]
        ///Port x reset bit y (y =
        ///0..15)
        br7: u1 = 0,
        ///BR8 [24:24]
        ///Port x reset bit y (y =
        ///0..15)
        br8: u1 = 0,
        ///BR9 [25:25]
        ///Port x reset bit y (y =
        ///0..15)
        br9: u1 = 0,
        ///BR10 [26:26]
        ///Port x reset bit y (y =
        ///0..15)
        br10: u1 = 0,
        ///BR11 [27:27]
        ///Port x reset bit y (y =
        ///0..15)
        br11: u1 = 0,
        ///BR12 [28:28]
        ///Port x reset bit y (y =
        ///0..15)
        br12: u1 = 0,
        ///BR13 [29:29]
        ///Port x reset bit y (y =
        ///0..15)
        br13: u1 = 0,
        ///BR14 [30:30]
        ///Port x reset bit y (y =
        ///0..15)
        br14: u1 = 0,
        ///BR15 [31:31]
        ///Port x reset bit y (y =
        ///0..15)
        br15: u1 = 0,
    };
    ///GPIO port bit set/reset
    ///register
    pub const bsrr = RegisterRW(void, bsrr_val).init(0x48000C00 + 0x18);

    //////////////////////////
    ///LCKR
    const lckr_val = packed struct {
        ///LCK0 [0:0]
        ///Port x lock bit y (y=
        ///0..15)
        lck0: u1 = 0,
        ///LCK1 [1:1]
        ///Port x lock bit y (y=
        ///0..15)
        lck1: u1 = 0,
        ///LCK2 [2:2]
        ///Port x lock bit y (y=
        ///0..15)
        lck2: u1 = 0,
        ///LCK3 [3:3]
        ///Port x lock bit y (y=
        ///0..15)
        lck3: u1 = 0,
        ///LCK4 [4:4]
        ///Port x lock bit y (y=
        ///0..15)
        lck4: u1 = 0,
        ///LCK5 [5:5]
        ///Port x lock bit y (y=
        ///0..15)
        lck5: u1 = 0,
        ///LCK6 [6:6]
        ///Port x lock bit y (y=
        ///0..15)
        lck6: u1 = 0,
        ///LCK7 [7:7]
        ///Port x lock bit y (y=
        ///0..15)
        lck7: u1 = 0,
        ///LCK8 [8:8]
        ///Port x lock bit y (y=
        ///0..15)
        lck8: u1 = 0,
        ///LCK9 [9:9]
        ///Port x lock bit y (y=
        ///0..15)
        lck9: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCK10 [10:10]
        ///Port x lock bit y (y=
        ///0..15)
        lck10: u1 = 0,
        ///LCK11 [11:11]
        ///Port x lock bit y (y=
        ///0..15)
        lck11: u1 = 0,
        ///LCK12 [12:12]
        ///Port x lock bit y (y=
        ///0..15)
        lck12: u1 = 0,
        ///LCK13 [13:13]
        ///Port x lock bit y (y=
        ///0..15)
        lck13: u1 = 0,
        ///LCK14 [14:14]
        ///Port x lock bit y (y=
        ///0..15)
        lck14: u1 = 0,
        ///LCK15 [15:15]
        ///Port x lock bit y (y=
        ///0..15)
        lck15: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCKK [16:16]
        ///Port x lock bit y
        lckk: packed enum(u1) {
            ///Port configuration lock key not active
            not_active = 0,
            ///Port configuration lock key active
            active = 1,
        } = .not_active,
        _unused17: u15 = 0,
    };
    ///GPIO port configuration lock
    ///register
    pub const lckr = Register(lckr_val).init(0x48000C00 + 0x1C);

    //////////////////////////
    ///AFRL
    const afrl_val = packed struct {
        ///AFRL0 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl0: u4 = 0,
        ///AFRL1 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl1: u4 = 0,
        ///AFRL2 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl2: u4 = 0,
        ///AFRL3 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl3: u4 = 0,
        ///AFRL4 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl4: u4 = 0,
        ///AFRL5 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl5: u4 = 0,
        ///AFRL6 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl6: u4 = 0,
        ///AFRL7 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl7: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function low
    ///register
    pub const afrl = Register(afrl_val).init(0x48000C00 + 0x20);

    //////////////////////////
    ///AFRH
    const afrh_val = packed struct {
        ///AFRH8 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh8: u4 = 0,
        ///AFRH9 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh9: u4 = 0,
        ///AFRH10 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh10: u4 = 0,
        ///AFRH11 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh11: u4 = 0,
        ///AFRH12 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh12: u4 = 0,
        ///AFRH13 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh13: u4 = 0,
        ///AFRH14 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh14: u4 = 0,
        ///AFRH15 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh15: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function high
    ///register
    pub const afrh = Register(afrh_val).init(0x48000C00 + 0x24);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BR0 [0:0]
        ///Port x Reset bit y
        br0: u1 = 0,
        ///BR1 [1:1]
        ///Port x Reset bit y
        br1: u1 = 0,
        ///BR2 [2:2]
        ///Port x Reset bit y
        br2: u1 = 0,
        ///BR3 [3:3]
        ///Port x Reset bit y
        br3: u1 = 0,
        ///BR4 [4:4]
        ///Port x Reset bit y
        br4: u1 = 0,
        ///BR5 [5:5]
        ///Port x Reset bit y
        br5: u1 = 0,
        ///BR6 [6:6]
        ///Port x Reset bit y
        br6: u1 = 0,
        ///BR7 [7:7]
        ///Port x Reset bit y
        br7: u1 = 0,
        ///BR8 [8:8]
        ///Port x Reset bit y
        br8: u1 = 0,
        ///BR9 [9:9]
        ///Port x Reset bit y
        br9: u1 = 0,
        ///BR10 [10:10]
        ///Port x Reset bit y
        br10: u1 = 0,
        ///BR11 [11:11]
        ///Port x Reset bit y
        br11: u1 = 0,
        ///BR12 [12:12]
        ///Port x Reset bit y
        br12: u1 = 0,
        ///BR13 [13:13]
        ///Port x Reset bit y
        br13: u1 = 0,
        ///BR14 [14:14]
        ///Port x Reset bit y
        br14: u1 = 0,
        ///BR15 [15:15]
        ///Port x Reset bit y
        br15: u1 = 0,
        _unused16: u16 = 0,
    };
    ///Port bit reset register
    pub const brr = RegisterRW(void, brr_val).init(0x48000C00 + 0x28);
};

///General-purpose I/Os
pub const gpioc = struct {

    //////////////////////////
    ///MODER
    const moder_val = packed struct {
        ///MODER0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        moder0: u2 = 0,
        ///MODER1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        moder1: u2 = 0,
        ///MODER2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        moder2: u2 = 0,
        ///MODER3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        moder3: u2 = 0,
        ///MODER4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        moder4: u2 = 0,
        ///MODER5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        moder5: u2 = 0,
        ///MODER6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        moder6: u2 = 0,
        ///MODER7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        moder7: u2 = 0,
        ///MODER8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        moder8: u2 = 0,
        ///MODER9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        moder9: u2 = 0,
        ///MODER10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        moder10: u2 = 0,
        ///MODER11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        moder11: u2 = 0,
        ///MODER12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        moder12: u2 = 0,
        ///MODER13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        moder13: u2 = 0,
        ///MODER14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        moder14: u2 = 0,
        ///MODER15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        moder15: packed enum(u2) {
            ///Input mode (reset state)
            input = 0,
            ///General purpose output mode
            output = 1,
            ///Alternate function mode
            alternate = 2,
            ///Analog mode
            analog = 3,
        } = .input,
    };
    ///GPIO port mode register
    pub const moder = Register(moder_val).init(0x48000800 + 0x0);

    //////////////////////////
    ///OTYPER
    const otyper_val = packed struct {
        ///OT0 [0:0]
        ///Port x configuration bit 0
        ot0: u1 = 0,
        ///OT1 [1:1]
        ///Port x configuration bit 1
        ot1: u1 = 0,
        ///OT2 [2:2]
        ///Port x configuration bit 2
        ot2: u1 = 0,
        ///OT3 [3:3]
        ///Port x configuration bit 3
        ot3: u1 = 0,
        ///OT4 [4:4]
        ///Port x configuration bit 4
        ot4: u1 = 0,
        ///OT5 [5:5]
        ///Port x configuration bit 5
        ot5: u1 = 0,
        ///OT6 [6:6]
        ///Port x configuration bit 6
        ot6: u1 = 0,
        ///OT7 [7:7]
        ///Port x configuration bit 7
        ot7: u1 = 0,
        ///OT8 [8:8]
        ///Port x configuration bit 8
        ot8: u1 = 0,
        ///OT9 [9:9]
        ///Port x configuration bit 9
        ot9: u1 = 0,
        ///OT10 [10:10]
        ///Port x configuration bit
        ///10
        ot10: u1 = 0,
        ///OT11 [11:11]
        ///Port x configuration bit
        ///11
        ot11: u1 = 0,
        ///OT12 [12:12]
        ///Port x configuration bit
        ///12
        ot12: u1 = 0,
        ///OT13 [13:13]
        ///Port x configuration bit
        ///13
        ot13: u1 = 0,
        ///OT14 [14:14]
        ///Port x configuration bit
        ///14
        ot14: u1 = 0,
        ///OT15 [15:15]
        ///Port x configuration bit
        ///15
        ot15: packed enum(u1) {
            ///Output push-pull (reset state)
            push_pull = 0,
            ///Output open-drain
            open_drain = 1,
        } = .push_pull,
        _unused16: u16 = 0,
    };
    ///GPIO port output type register
    pub const otyper = Register(otyper_val).init(0x48000800 + 0x4);

    //////////////////////////
    ///OSPEEDR
    const ospeedr_val = packed struct {
        ///OSPEEDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr0: u2 = 0,
        ///OSPEEDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr1: u2 = 0,
        ///OSPEEDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr2: u2 = 0,
        ///OSPEEDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr3: u2 = 0,
        ///OSPEEDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr4: u2 = 0,
        ///OSPEEDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr5: u2 = 0,
        ///OSPEEDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr6: u2 = 0,
        ///OSPEEDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr7: u2 = 0,
        ///OSPEEDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr8: u2 = 0,
        ///OSPEEDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr9: u2 = 0,
        ///OSPEEDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr10: u2 = 0,
        ///OSPEEDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr11: u2 = 0,
        ///OSPEEDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr12: u2 = 0,
        ///OSPEEDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr13: u2 = 0,
        ///OSPEEDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr14: u2 = 0,
        ///OSPEEDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr15: packed enum(u2) {
            ///Low speed
            low_speed = 0,
            ///Medium speed
            medium_speed = 1,
            ///High speed
            high_speed = 2,
            ///Very high speed
            very_high_speed = 3,
        } = .low_speed,
    };
    ///GPIO port output speed
    ///register
    pub const ospeedr = Register(ospeedr_val).init(0x48000800 + 0x8);

    //////////////////////////
    ///PUPDR
    const pupdr_val = packed struct {
        ///PUPDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr0: u2 = 0,
        ///PUPDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr1: u2 = 0,
        ///PUPDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr2: u2 = 0,
        ///PUPDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr3: u2 = 0,
        ///PUPDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr4: u2 = 0,
        ///PUPDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr5: u2 = 0,
        ///PUPDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr6: u2 = 0,
        ///PUPDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr7: u2 = 0,
        ///PUPDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr8: u2 = 0,
        ///PUPDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr9: u2 = 0,
        ///PUPDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr10: u2 = 0,
        ///PUPDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr11: u2 = 0,
        ///PUPDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr12: u2 = 0,
        ///PUPDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr13: u2 = 0,
        ///PUPDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr14: u2 = 0,
        ///PUPDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr15: packed enum(u2) {
            ///No pull-up, pull-down
            floating = 0,
            ///Pull-up
            pull_up = 1,
            ///Pull-down
            pull_down = 2,
        } = .floating,
    };
    ///GPIO port pull-up/pull-down
    ///register
    pub const pupdr = Register(pupdr_val).init(0x48000800 + 0xC);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR0 [0:0]
        ///Port input data (y =
        ///0..15)
        idr0: u1 = 0,
        ///IDR1 [1:1]
        ///Port input data (y =
        ///0..15)
        idr1: u1 = 0,
        ///IDR2 [2:2]
        ///Port input data (y =
        ///0..15)
        idr2: u1 = 0,
        ///IDR3 [3:3]
        ///Port input data (y =
        ///0..15)
        idr3: u1 = 0,
        ///IDR4 [4:4]
        ///Port input data (y =
        ///0..15)
        idr4: u1 = 0,
        ///IDR5 [5:5]
        ///Port input data (y =
        ///0..15)
        idr5: u1 = 0,
        ///IDR6 [6:6]
        ///Port input data (y =
        ///0..15)
        idr6: u1 = 0,
        ///IDR7 [7:7]
        ///Port input data (y =
        ///0..15)
        idr7: u1 = 0,
        ///IDR8 [8:8]
        ///Port input data (y =
        ///0..15)
        idr8: u1 = 0,
        ///IDR9 [9:9]
        ///Port input data (y =
        ///0..15)
        idr9: u1 = 0,
        ///IDR10 [10:10]
        ///Port input data (y =
        ///0..15)
        idr10: u1 = 0,
        ///IDR11 [11:11]
        ///Port input data (y =
        ///0..15)
        idr11: u1 = 0,
        ///IDR12 [12:12]
        ///Port input data (y =
        ///0..15)
        idr12: u1 = 0,
        ///IDR13 [13:13]
        ///Port input data (y =
        ///0..15)
        idr13: u1 = 0,
        ///IDR14 [14:14]
        ///Port input data (y =
        ///0..15)
        idr14: u1 = 0,
        ///IDR15 [15:15]
        ///Port input data (y =
        ///0..15)
        idr15: packed enum(u1) {
            ///Input is logic high
            high = 1,
            ///Input is logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port input data register
    pub const idr = RegisterRW(idr_val, void).init(0x48000800 + 0x10);

    //////////////////////////
    ///ODR
    const odr_val = packed struct {
        ///ODR0 [0:0]
        ///Port output data (y =
        ///0..15)
        odr0: u1 = 0,
        ///ODR1 [1:1]
        ///Port output data (y =
        ///0..15)
        odr1: u1 = 0,
        ///ODR2 [2:2]
        ///Port output data (y =
        ///0..15)
        odr2: u1 = 0,
        ///ODR3 [3:3]
        ///Port output data (y =
        ///0..15)
        odr3: u1 = 0,
        ///ODR4 [4:4]
        ///Port output data (y =
        ///0..15)
        odr4: u1 = 0,
        ///ODR5 [5:5]
        ///Port output data (y =
        ///0..15)
        odr5: u1 = 0,
        ///ODR6 [6:6]
        ///Port output data (y =
        ///0..15)
        odr6: u1 = 0,
        ///ODR7 [7:7]
        ///Port output data (y =
        ///0..15)
        odr7: u1 = 0,
        ///ODR8 [8:8]
        ///Port output data (y =
        ///0..15)
        odr8: u1 = 0,
        ///ODR9 [9:9]
        ///Port output data (y =
        ///0..15)
        odr9: u1 = 0,
        ///ODR10 [10:10]
        ///Port output data (y =
        ///0..15)
        odr10: u1 = 0,
        ///ODR11 [11:11]
        ///Port output data (y =
        ///0..15)
        odr11: u1 = 0,
        ///ODR12 [12:12]
        ///Port output data (y =
        ///0..15)
        odr12: u1 = 0,
        ///ODR13 [13:13]
        ///Port output data (y =
        ///0..15)
        odr13: u1 = 0,
        ///ODR14 [14:14]
        ///Port output data (y =
        ///0..15)
        odr14: u1 = 0,
        ///ODR15 [15:15]
        ///Port output data (y =
        ///0..15)
        odr15: packed enum(u1) {
            ///Set output to logic high
            high = 1,
            ///Set output to logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port output data register
    pub const odr = Register(odr_val).init(0x48000800 + 0x14);

    //////////////////////////
    ///BSRR
    const bsrr_val = packed struct {
        ///BS0 [0:0]
        ///Port x set bit y (y=
        ///0..15)
        bs0: u1 = 0,
        ///BS1 [1:1]
        ///Port x set bit y (y=
        ///0..15)
        bs1: u1 = 0,
        ///BS2 [2:2]
        ///Port x set bit y (y=
        ///0..15)
        bs2: u1 = 0,
        ///BS3 [3:3]
        ///Port x set bit y (y=
        ///0..15)
        bs3: u1 = 0,
        ///BS4 [4:4]
        ///Port x set bit y (y=
        ///0..15)
        bs4: u1 = 0,
        ///BS5 [5:5]
        ///Port x set bit y (y=
        ///0..15)
        bs5: u1 = 0,
        ///BS6 [6:6]
        ///Port x set bit y (y=
        ///0..15)
        bs6: u1 = 0,
        ///BS7 [7:7]
        ///Port x set bit y (y=
        ///0..15)
        bs7: u1 = 0,
        ///BS8 [8:8]
        ///Port x set bit y (y=
        ///0..15)
        bs8: u1 = 0,
        ///BS9 [9:9]
        ///Port x set bit y (y=
        ///0..15)
        bs9: u1 = 0,
        ///BS10 [10:10]
        ///Port x set bit y (y=
        ///0..15)
        bs10: u1 = 0,
        ///BS11 [11:11]
        ///Port x set bit y (y=
        ///0..15)
        bs11: u1 = 0,
        ///BS12 [12:12]
        ///Port x set bit y (y=
        ///0..15)
        bs12: u1 = 0,
        ///BS13 [13:13]
        ///Port x set bit y (y=
        ///0..15)
        bs13: u1 = 0,
        ///BS14 [14:14]
        ///Port x set bit y (y=
        ///0..15)
        bs14: u1 = 0,
        ///BS15 [15:15]
        ///Port x set bit y (y=
        ///0..15)
        bs15: u1 = 0,
        ///BR0 [16:16]
        ///Port x set bit y (y=
        ///0..15)
        br0: u1 = 0,
        ///BR1 [17:17]
        ///Port x reset bit y (y =
        ///0..15)
        br1: u1 = 0,
        ///BR2 [18:18]
        ///Port x reset bit y (y =
        ///0..15)
        br2: u1 = 0,
        ///BR3 [19:19]
        ///Port x reset bit y (y =
        ///0..15)
        br3: u1 = 0,
        ///BR4 [20:20]
        ///Port x reset bit y (y =
        ///0..15)
        br4: u1 = 0,
        ///BR5 [21:21]
        ///Port x reset bit y (y =
        ///0..15)
        br5: u1 = 0,
        ///BR6 [22:22]
        ///Port x reset bit y (y =
        ///0..15)
        br6: u1 = 0,
        ///BR7 [23:23]
        ///Port x reset bit y (y =
        ///0..15)
        br7: u1 = 0,
        ///BR8 [24:24]
        ///Port x reset bit y (y =
        ///0..15)
        br8: u1 = 0,
        ///BR9 [25:25]
        ///Port x reset bit y (y =
        ///0..15)
        br9: u1 = 0,
        ///BR10 [26:26]
        ///Port x reset bit y (y =
        ///0..15)
        br10: u1 = 0,
        ///BR11 [27:27]
        ///Port x reset bit y (y =
        ///0..15)
        br11: u1 = 0,
        ///BR12 [28:28]
        ///Port x reset bit y (y =
        ///0..15)
        br12: u1 = 0,
        ///BR13 [29:29]
        ///Port x reset bit y (y =
        ///0..15)
        br13: u1 = 0,
        ///BR14 [30:30]
        ///Port x reset bit y (y =
        ///0..15)
        br14: u1 = 0,
        ///BR15 [31:31]
        ///Port x reset bit y (y =
        ///0..15)
        br15: u1 = 0,
    };
    ///GPIO port bit set/reset
    ///register
    pub const bsrr = RegisterRW(void, bsrr_val).init(0x48000800 + 0x18);

    //////////////////////////
    ///LCKR
    const lckr_val = packed struct {
        ///LCK0 [0:0]
        ///Port x lock bit y (y=
        ///0..15)
        lck0: u1 = 0,
        ///LCK1 [1:1]
        ///Port x lock bit y (y=
        ///0..15)
        lck1: u1 = 0,
        ///LCK2 [2:2]
        ///Port x lock bit y (y=
        ///0..15)
        lck2: u1 = 0,
        ///LCK3 [3:3]
        ///Port x lock bit y (y=
        ///0..15)
        lck3: u1 = 0,
        ///LCK4 [4:4]
        ///Port x lock bit y (y=
        ///0..15)
        lck4: u1 = 0,
        ///LCK5 [5:5]
        ///Port x lock bit y (y=
        ///0..15)
        lck5: u1 = 0,
        ///LCK6 [6:6]
        ///Port x lock bit y (y=
        ///0..15)
        lck6: u1 = 0,
        ///LCK7 [7:7]
        ///Port x lock bit y (y=
        ///0..15)
        lck7: u1 = 0,
        ///LCK8 [8:8]
        ///Port x lock bit y (y=
        ///0..15)
        lck8: u1 = 0,
        ///LCK9 [9:9]
        ///Port x lock bit y (y=
        ///0..15)
        lck9: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCK10 [10:10]
        ///Port x lock bit y (y=
        ///0..15)
        lck10: u1 = 0,
        ///LCK11 [11:11]
        ///Port x lock bit y (y=
        ///0..15)
        lck11: u1 = 0,
        ///LCK12 [12:12]
        ///Port x lock bit y (y=
        ///0..15)
        lck12: u1 = 0,
        ///LCK13 [13:13]
        ///Port x lock bit y (y=
        ///0..15)
        lck13: u1 = 0,
        ///LCK14 [14:14]
        ///Port x lock bit y (y=
        ///0..15)
        lck14: u1 = 0,
        ///LCK15 [15:15]
        ///Port x lock bit y (y=
        ///0..15)
        lck15: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCKK [16:16]
        ///Port x lock bit y
        lckk: packed enum(u1) {
            ///Port configuration lock key not active
            not_active = 0,
            ///Port configuration lock key active
            active = 1,
        } = .not_active,
        _unused17: u15 = 0,
    };
    ///GPIO port configuration lock
    ///register
    pub const lckr = Register(lckr_val).init(0x48000800 + 0x1C);

    //////////////////////////
    ///AFRL
    const afrl_val = packed struct {
        ///AFRL0 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl0: u4 = 0,
        ///AFRL1 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl1: u4 = 0,
        ///AFRL2 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl2: u4 = 0,
        ///AFRL3 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl3: u4 = 0,
        ///AFRL4 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl4: u4 = 0,
        ///AFRL5 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl5: u4 = 0,
        ///AFRL6 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl6: u4 = 0,
        ///AFRL7 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl7: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function low
    ///register
    pub const afrl = Register(afrl_val).init(0x48000800 + 0x20);

    //////////////////////////
    ///AFRH
    const afrh_val = packed struct {
        ///AFRH8 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh8: u4 = 0,
        ///AFRH9 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh9: u4 = 0,
        ///AFRH10 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh10: u4 = 0,
        ///AFRH11 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh11: u4 = 0,
        ///AFRH12 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh12: u4 = 0,
        ///AFRH13 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh13: u4 = 0,
        ///AFRH14 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh14: u4 = 0,
        ///AFRH15 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh15: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function high
    ///register
    pub const afrh = Register(afrh_val).init(0x48000800 + 0x24);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BR0 [0:0]
        ///Port x Reset bit y
        br0: u1 = 0,
        ///BR1 [1:1]
        ///Port x Reset bit y
        br1: u1 = 0,
        ///BR2 [2:2]
        ///Port x Reset bit y
        br2: u1 = 0,
        ///BR3 [3:3]
        ///Port x Reset bit y
        br3: u1 = 0,
        ///BR4 [4:4]
        ///Port x Reset bit y
        br4: u1 = 0,
        ///BR5 [5:5]
        ///Port x Reset bit y
        br5: u1 = 0,
        ///BR6 [6:6]
        ///Port x Reset bit y
        br6: u1 = 0,
        ///BR7 [7:7]
        ///Port x Reset bit y
        br7: u1 = 0,
        ///BR8 [8:8]
        ///Port x Reset bit y
        br8: u1 = 0,
        ///BR9 [9:9]
        ///Port x Reset bit y
        br9: u1 = 0,
        ///BR10 [10:10]
        ///Port x Reset bit y
        br10: u1 = 0,
        ///BR11 [11:11]
        ///Port x Reset bit y
        br11: u1 = 0,
        ///BR12 [12:12]
        ///Port x Reset bit y
        br12: u1 = 0,
        ///BR13 [13:13]
        ///Port x Reset bit y
        br13: u1 = 0,
        ///BR14 [14:14]
        ///Port x Reset bit y
        br14: u1 = 0,
        ///BR15 [15:15]
        ///Port x Reset bit y
        br15: u1 = 0,
        _unused16: u16 = 0,
    };
    ///Port bit reset register
    pub const brr = RegisterRW(void, brr_val).init(0x48000800 + 0x28);
};

///General-purpose I/Os
pub const gpiob = struct {

    //////////////////////////
    ///MODER
    const moder_val = packed struct {
        ///MODER0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        moder0: u2 = 0,
        ///MODER1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        moder1: u2 = 0,
        ///MODER2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        moder2: u2 = 0,
        ///MODER3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        moder3: u2 = 0,
        ///MODER4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        moder4: u2 = 0,
        ///MODER5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        moder5: u2 = 0,
        ///MODER6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        moder6: u2 = 0,
        ///MODER7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        moder7: u2 = 0,
        ///MODER8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        moder8: u2 = 0,
        ///MODER9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        moder9: u2 = 0,
        ///MODER10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        moder10: u2 = 0,
        ///MODER11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        moder11: u2 = 0,
        ///MODER12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        moder12: u2 = 0,
        ///MODER13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        moder13: u2 = 0,
        ///MODER14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        moder14: u2 = 0,
        ///MODER15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        moder15: packed enum(u2) {
            ///Input mode (reset state)
            input = 0,
            ///General purpose output mode
            output = 1,
            ///Alternate function mode
            alternate = 2,
            ///Analog mode
            analog = 3,
        } = .input,
    };
    ///GPIO port mode register
    pub const moder = Register(moder_val).init(0x48000400 + 0x0);

    //////////////////////////
    ///OTYPER
    const otyper_val = packed struct {
        ///OT0 [0:0]
        ///Port x configuration bit 0
        ot0: u1 = 0,
        ///OT1 [1:1]
        ///Port x configuration bit 1
        ot1: u1 = 0,
        ///OT2 [2:2]
        ///Port x configuration bit 2
        ot2: u1 = 0,
        ///OT3 [3:3]
        ///Port x configuration bit 3
        ot3: u1 = 0,
        ///OT4 [4:4]
        ///Port x configuration bit 4
        ot4: u1 = 0,
        ///OT5 [5:5]
        ///Port x configuration bit 5
        ot5: u1 = 0,
        ///OT6 [6:6]
        ///Port x configuration bit 6
        ot6: u1 = 0,
        ///OT7 [7:7]
        ///Port x configuration bit 7
        ot7: u1 = 0,
        ///OT8 [8:8]
        ///Port x configuration bit 8
        ot8: u1 = 0,
        ///OT9 [9:9]
        ///Port x configuration bit 9
        ot9: u1 = 0,
        ///OT10 [10:10]
        ///Port x configuration bit
        ///10
        ot10: u1 = 0,
        ///OT11 [11:11]
        ///Port x configuration bit
        ///11
        ot11: u1 = 0,
        ///OT12 [12:12]
        ///Port x configuration bit
        ///12
        ot12: u1 = 0,
        ///OT13 [13:13]
        ///Port x configuration bit
        ///13
        ot13: u1 = 0,
        ///OT14 [14:14]
        ///Port x configuration bit
        ///14
        ot14: u1 = 0,
        ///OT15 [15:15]
        ///Port x configuration bit
        ///15
        ot15: packed enum(u1) {
            ///Output push-pull (reset state)
            push_pull = 0,
            ///Output open-drain
            open_drain = 1,
        } = .push_pull,
        _unused16: u16 = 0,
    };
    ///GPIO port output type register
    pub const otyper = Register(otyper_val).init(0x48000400 + 0x4);

    //////////////////////////
    ///OSPEEDR
    const ospeedr_val = packed struct {
        ///OSPEEDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr0: u2 = 0,
        ///OSPEEDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr1: u2 = 0,
        ///OSPEEDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr2: u2 = 0,
        ///OSPEEDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr3: u2 = 0,
        ///OSPEEDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr4: u2 = 0,
        ///OSPEEDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr5: u2 = 0,
        ///OSPEEDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr6: u2 = 0,
        ///OSPEEDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr7: u2 = 0,
        ///OSPEEDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr8: u2 = 0,
        ///OSPEEDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr9: u2 = 0,
        ///OSPEEDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr10: u2 = 0,
        ///OSPEEDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr11: u2 = 0,
        ///OSPEEDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr12: u2 = 0,
        ///OSPEEDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr13: u2 = 0,
        ///OSPEEDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr14: u2 = 0,
        ///OSPEEDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr15: packed enum(u2) {
            ///Low speed
            low_speed = 0,
            ///Medium speed
            medium_speed = 1,
            ///High speed
            high_speed = 2,
            ///Very high speed
            very_high_speed = 3,
        } = .low_speed,
    };
    ///GPIO port output speed
    ///register
    pub const ospeedr = Register(ospeedr_val).init(0x48000400 + 0x8);

    //////////////////////////
    ///PUPDR
    const pupdr_val = packed struct {
        ///PUPDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr0: u2 = 0,
        ///PUPDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr1: u2 = 0,
        ///PUPDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr2: u2 = 0,
        ///PUPDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr3: u2 = 0,
        ///PUPDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr4: u2 = 0,
        ///PUPDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr5: u2 = 0,
        ///PUPDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr6: u2 = 0,
        ///PUPDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr7: u2 = 0,
        ///PUPDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr8: u2 = 0,
        ///PUPDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr9: u2 = 0,
        ///PUPDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr10: u2 = 0,
        ///PUPDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr11: u2 = 0,
        ///PUPDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr12: u2 = 0,
        ///PUPDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr13: u2 = 0,
        ///PUPDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr14: u2 = 0,
        ///PUPDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr15: packed enum(u2) {
            ///No pull-up, pull-down
            floating = 0,
            ///Pull-up
            pull_up = 1,
            ///Pull-down
            pull_down = 2,
        } = .floating,
    };
    ///GPIO port pull-up/pull-down
    ///register
    pub const pupdr = Register(pupdr_val).init(0x48000400 + 0xC);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR0 [0:0]
        ///Port input data (y =
        ///0..15)
        idr0: u1 = 0,
        ///IDR1 [1:1]
        ///Port input data (y =
        ///0..15)
        idr1: u1 = 0,
        ///IDR2 [2:2]
        ///Port input data (y =
        ///0..15)
        idr2: u1 = 0,
        ///IDR3 [3:3]
        ///Port input data (y =
        ///0..15)
        idr3: u1 = 0,
        ///IDR4 [4:4]
        ///Port input data (y =
        ///0..15)
        idr4: u1 = 0,
        ///IDR5 [5:5]
        ///Port input data (y =
        ///0..15)
        idr5: u1 = 0,
        ///IDR6 [6:6]
        ///Port input data (y =
        ///0..15)
        idr6: u1 = 0,
        ///IDR7 [7:7]
        ///Port input data (y =
        ///0..15)
        idr7: u1 = 0,
        ///IDR8 [8:8]
        ///Port input data (y =
        ///0..15)
        idr8: u1 = 0,
        ///IDR9 [9:9]
        ///Port input data (y =
        ///0..15)
        idr9: u1 = 0,
        ///IDR10 [10:10]
        ///Port input data (y =
        ///0..15)
        idr10: u1 = 0,
        ///IDR11 [11:11]
        ///Port input data (y =
        ///0..15)
        idr11: u1 = 0,
        ///IDR12 [12:12]
        ///Port input data (y =
        ///0..15)
        idr12: u1 = 0,
        ///IDR13 [13:13]
        ///Port input data (y =
        ///0..15)
        idr13: u1 = 0,
        ///IDR14 [14:14]
        ///Port input data (y =
        ///0..15)
        idr14: u1 = 0,
        ///IDR15 [15:15]
        ///Port input data (y =
        ///0..15)
        idr15: packed enum(u1) {
            ///Input is logic high
            high = 1,
            ///Input is logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port input data register
    pub const idr = RegisterRW(idr_val, void).init(0x48000400 + 0x10);

    //////////////////////////
    ///ODR
    const odr_val = packed struct {
        ///ODR0 [0:0]
        ///Port output data (y =
        ///0..15)
        odr0: u1 = 0,
        ///ODR1 [1:1]
        ///Port output data (y =
        ///0..15)
        odr1: u1 = 0,
        ///ODR2 [2:2]
        ///Port output data (y =
        ///0..15)
        odr2: u1 = 0,
        ///ODR3 [3:3]
        ///Port output data (y =
        ///0..15)
        odr3: u1 = 0,
        ///ODR4 [4:4]
        ///Port output data (y =
        ///0..15)
        odr4: u1 = 0,
        ///ODR5 [5:5]
        ///Port output data (y =
        ///0..15)
        odr5: u1 = 0,
        ///ODR6 [6:6]
        ///Port output data (y =
        ///0..15)
        odr6: u1 = 0,
        ///ODR7 [7:7]
        ///Port output data (y =
        ///0..15)
        odr7: u1 = 0,
        ///ODR8 [8:8]
        ///Port output data (y =
        ///0..15)
        odr8: u1 = 0,
        ///ODR9 [9:9]
        ///Port output data (y =
        ///0..15)
        odr9: u1 = 0,
        ///ODR10 [10:10]
        ///Port output data (y =
        ///0..15)
        odr10: u1 = 0,
        ///ODR11 [11:11]
        ///Port output data (y =
        ///0..15)
        odr11: u1 = 0,
        ///ODR12 [12:12]
        ///Port output data (y =
        ///0..15)
        odr12: u1 = 0,
        ///ODR13 [13:13]
        ///Port output data (y =
        ///0..15)
        odr13: u1 = 0,
        ///ODR14 [14:14]
        ///Port output data (y =
        ///0..15)
        odr14: u1 = 0,
        ///ODR15 [15:15]
        ///Port output data (y =
        ///0..15)
        odr15: packed enum(u1) {
            ///Set output to logic high
            high = 1,
            ///Set output to logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port output data register
    pub const odr = Register(odr_val).init(0x48000400 + 0x14);

    //////////////////////////
    ///BSRR
    const bsrr_val = packed struct {
        ///BS0 [0:0]
        ///Port x set bit y (y=
        ///0..15)
        bs0: u1 = 0,
        ///BS1 [1:1]
        ///Port x set bit y (y=
        ///0..15)
        bs1: u1 = 0,
        ///BS2 [2:2]
        ///Port x set bit y (y=
        ///0..15)
        bs2: u1 = 0,
        ///BS3 [3:3]
        ///Port x set bit y (y=
        ///0..15)
        bs3: u1 = 0,
        ///BS4 [4:4]
        ///Port x set bit y (y=
        ///0..15)
        bs4: u1 = 0,
        ///BS5 [5:5]
        ///Port x set bit y (y=
        ///0..15)
        bs5: u1 = 0,
        ///BS6 [6:6]
        ///Port x set bit y (y=
        ///0..15)
        bs6: u1 = 0,
        ///BS7 [7:7]
        ///Port x set bit y (y=
        ///0..15)
        bs7: u1 = 0,
        ///BS8 [8:8]
        ///Port x set bit y (y=
        ///0..15)
        bs8: u1 = 0,
        ///BS9 [9:9]
        ///Port x set bit y (y=
        ///0..15)
        bs9: u1 = 0,
        ///BS10 [10:10]
        ///Port x set bit y (y=
        ///0..15)
        bs10: u1 = 0,
        ///BS11 [11:11]
        ///Port x set bit y (y=
        ///0..15)
        bs11: u1 = 0,
        ///BS12 [12:12]
        ///Port x set bit y (y=
        ///0..15)
        bs12: u1 = 0,
        ///BS13 [13:13]
        ///Port x set bit y (y=
        ///0..15)
        bs13: u1 = 0,
        ///BS14 [14:14]
        ///Port x set bit y (y=
        ///0..15)
        bs14: u1 = 0,
        ///BS15 [15:15]
        ///Port x set bit y (y=
        ///0..15)
        bs15: u1 = 0,
        ///BR0 [16:16]
        ///Port x set bit y (y=
        ///0..15)
        br0: u1 = 0,
        ///BR1 [17:17]
        ///Port x reset bit y (y =
        ///0..15)
        br1: u1 = 0,
        ///BR2 [18:18]
        ///Port x reset bit y (y =
        ///0..15)
        br2: u1 = 0,
        ///BR3 [19:19]
        ///Port x reset bit y (y =
        ///0..15)
        br3: u1 = 0,
        ///BR4 [20:20]
        ///Port x reset bit y (y =
        ///0..15)
        br4: u1 = 0,
        ///BR5 [21:21]
        ///Port x reset bit y (y =
        ///0..15)
        br5: u1 = 0,
        ///BR6 [22:22]
        ///Port x reset bit y (y =
        ///0..15)
        br6: u1 = 0,
        ///BR7 [23:23]
        ///Port x reset bit y (y =
        ///0..15)
        br7: u1 = 0,
        ///BR8 [24:24]
        ///Port x reset bit y (y =
        ///0..15)
        br8: u1 = 0,
        ///BR9 [25:25]
        ///Port x reset bit y (y =
        ///0..15)
        br9: u1 = 0,
        ///BR10 [26:26]
        ///Port x reset bit y (y =
        ///0..15)
        br10: u1 = 0,
        ///BR11 [27:27]
        ///Port x reset bit y (y =
        ///0..15)
        br11: u1 = 0,
        ///BR12 [28:28]
        ///Port x reset bit y (y =
        ///0..15)
        br12: u1 = 0,
        ///BR13 [29:29]
        ///Port x reset bit y (y =
        ///0..15)
        br13: u1 = 0,
        ///BR14 [30:30]
        ///Port x reset bit y (y =
        ///0..15)
        br14: u1 = 0,
        ///BR15 [31:31]
        ///Port x reset bit y (y =
        ///0..15)
        br15: u1 = 0,
    };
    ///GPIO port bit set/reset
    ///register
    pub const bsrr = RegisterRW(void, bsrr_val).init(0x48000400 + 0x18);

    //////////////////////////
    ///LCKR
    const lckr_val = packed struct {
        ///LCK0 [0:0]
        ///Port x lock bit y (y=
        ///0..15)
        lck0: u1 = 0,
        ///LCK1 [1:1]
        ///Port x lock bit y (y=
        ///0..15)
        lck1: u1 = 0,
        ///LCK2 [2:2]
        ///Port x lock bit y (y=
        ///0..15)
        lck2: u1 = 0,
        ///LCK3 [3:3]
        ///Port x lock bit y (y=
        ///0..15)
        lck3: u1 = 0,
        ///LCK4 [4:4]
        ///Port x lock bit y (y=
        ///0..15)
        lck4: u1 = 0,
        ///LCK5 [5:5]
        ///Port x lock bit y (y=
        ///0..15)
        lck5: u1 = 0,
        ///LCK6 [6:6]
        ///Port x lock bit y (y=
        ///0..15)
        lck6: u1 = 0,
        ///LCK7 [7:7]
        ///Port x lock bit y (y=
        ///0..15)
        lck7: u1 = 0,
        ///LCK8 [8:8]
        ///Port x lock bit y (y=
        ///0..15)
        lck8: u1 = 0,
        ///LCK9 [9:9]
        ///Port x lock bit y (y=
        ///0..15)
        lck9: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCK10 [10:10]
        ///Port x lock bit y (y=
        ///0..15)
        lck10: u1 = 0,
        ///LCK11 [11:11]
        ///Port x lock bit y (y=
        ///0..15)
        lck11: u1 = 0,
        ///LCK12 [12:12]
        ///Port x lock bit y (y=
        ///0..15)
        lck12: u1 = 0,
        ///LCK13 [13:13]
        ///Port x lock bit y (y=
        ///0..15)
        lck13: u1 = 0,
        ///LCK14 [14:14]
        ///Port x lock bit y (y=
        ///0..15)
        lck14: u1 = 0,
        ///LCK15 [15:15]
        ///Port x lock bit y (y=
        ///0..15)
        lck15: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCKK [16:16]
        ///Port x lock bit y
        lckk: packed enum(u1) {
            ///Port configuration lock key not active
            not_active = 0,
            ///Port configuration lock key active
            active = 1,
        } = .not_active,
        _unused17: u15 = 0,
    };
    ///GPIO port configuration lock
    ///register
    pub const lckr = Register(lckr_val).init(0x48000400 + 0x1C);

    //////////////////////////
    ///AFRL
    const afrl_val = packed struct {
        ///AFRL0 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl0: u4 = 0,
        ///AFRL1 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl1: u4 = 0,
        ///AFRL2 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl2: u4 = 0,
        ///AFRL3 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl3: u4 = 0,
        ///AFRL4 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl4: u4 = 0,
        ///AFRL5 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl5: u4 = 0,
        ///AFRL6 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl6: u4 = 0,
        ///AFRL7 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl7: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function low
    ///register
    pub const afrl = Register(afrl_val).init(0x48000400 + 0x20);

    //////////////////////////
    ///AFRH
    const afrh_val = packed struct {
        ///AFRH8 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh8: u4 = 0,
        ///AFRH9 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh9: u4 = 0,
        ///AFRH10 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh10: u4 = 0,
        ///AFRH11 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh11: u4 = 0,
        ///AFRH12 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh12: u4 = 0,
        ///AFRH13 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh13: u4 = 0,
        ///AFRH14 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh14: u4 = 0,
        ///AFRH15 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh15: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function high
    ///register
    pub const afrh = Register(afrh_val).init(0x48000400 + 0x24);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BR0 [0:0]
        ///Port x Reset bit y
        br0: u1 = 0,
        ///BR1 [1:1]
        ///Port x Reset bit y
        br1: u1 = 0,
        ///BR2 [2:2]
        ///Port x Reset bit y
        br2: u1 = 0,
        ///BR3 [3:3]
        ///Port x Reset bit y
        br3: u1 = 0,
        ///BR4 [4:4]
        ///Port x Reset bit y
        br4: u1 = 0,
        ///BR5 [5:5]
        ///Port x Reset bit y
        br5: u1 = 0,
        ///BR6 [6:6]
        ///Port x Reset bit y
        br6: u1 = 0,
        ///BR7 [7:7]
        ///Port x Reset bit y
        br7: u1 = 0,
        ///BR8 [8:8]
        ///Port x Reset bit y
        br8: u1 = 0,
        ///BR9 [9:9]
        ///Port x Reset bit y
        br9: u1 = 0,
        ///BR10 [10:10]
        ///Port x Reset bit y
        br10: u1 = 0,
        ///BR11 [11:11]
        ///Port x Reset bit y
        br11: u1 = 0,
        ///BR12 [12:12]
        ///Port x Reset bit y
        br12: u1 = 0,
        ///BR13 [13:13]
        ///Port x Reset bit y
        br13: u1 = 0,
        ///BR14 [14:14]
        ///Port x Reset bit y
        br14: u1 = 0,
        ///BR15 [15:15]
        ///Port x Reset bit y
        br15: u1 = 0,
        _unused16: u16 = 0,
    };
    ///Port bit reset register
    pub const brr = RegisterRW(void, brr_val).init(0x48000400 + 0x28);
};

///General-purpose I/Os
pub const gpioa = struct {

    //////////////////////////
    ///MODER
    const moder_val = packed struct {
        ///MODER0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        moder0: u2 = 0,
        ///MODER1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        moder1: u2 = 0,
        ///MODER2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        moder2: u2 = 0,
        ///MODER3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        moder3: u2 = 0,
        ///MODER4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        moder4: u2 = 0,
        ///MODER5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        moder5: u2 = 0,
        ///MODER6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        moder6: u2 = 0,
        ///MODER7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        moder7: u2 = 0,
        ///MODER8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        moder8: u2 = 0,
        ///MODER9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        moder9: u2 = 0,
        ///MODER10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        moder10: u2 = 0,
        ///MODER11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        moder11: u2 = 0,
        ///MODER12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        moder12: u2 = 0,
        ///MODER13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        moder13: u2 = 2,
        ///MODER14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        moder14: u2 = 2,
        ///MODER15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        moder15: packed enum(u2) {
            ///Input mode (reset state)
            input = 0,
            ///General purpose output mode
            output = 1,
            ///Alternate function mode
            alternate = 2,
            ///Analog mode
            analog = 3,
        } = .input,
    };
    ///GPIO port mode register
    pub const moder = Register(moder_val).init(0x48000000 + 0x0);

    //////////////////////////
    ///OTYPER
    const otyper_val = packed struct {
        ///OT0 [0:0]
        ///Port x configuration bits (y =
        ///0..15)
        ot0: u1 = 0,
        ///OT1 [1:1]
        ///Port x configuration bits (y =
        ///0..15)
        ot1: u1 = 0,
        ///OT2 [2:2]
        ///Port x configuration bits (y =
        ///0..15)
        ot2: u1 = 0,
        ///OT3 [3:3]
        ///Port x configuration bits (y =
        ///0..15)
        ot3: u1 = 0,
        ///OT4 [4:4]
        ///Port x configuration bits (y =
        ///0..15)
        ot4: u1 = 0,
        ///OT5 [5:5]
        ///Port x configuration bits (y =
        ///0..15)
        ot5: u1 = 0,
        ///OT6 [6:6]
        ///Port x configuration bits (y =
        ///0..15)
        ot6: u1 = 0,
        ///OT7 [7:7]
        ///Port x configuration bits (y =
        ///0..15)
        ot7: u1 = 0,
        ///OT8 [8:8]
        ///Port x configuration bits (y =
        ///0..15)
        ot8: u1 = 0,
        ///OT9 [9:9]
        ///Port x configuration bits (y =
        ///0..15)
        ot9: u1 = 0,
        ///OT10 [10:10]
        ///Port x configuration bits (y =
        ///0..15)
        ot10: u1 = 0,
        ///OT11 [11:11]
        ///Port x configuration bits (y =
        ///0..15)
        ot11: u1 = 0,
        ///OT12 [12:12]
        ///Port x configuration bits (y =
        ///0..15)
        ot12: u1 = 0,
        ///OT13 [13:13]
        ///Port x configuration bits (y =
        ///0..15)
        ot13: u1 = 0,
        ///OT14 [14:14]
        ///Port x configuration bits (y =
        ///0..15)
        ot14: u1 = 0,
        ///OT15 [15:15]
        ///Port x configuration bits (y =
        ///0..15)
        ot15: packed enum(u1) {
            ///Output push-pull (reset state)
            push_pull = 0,
            ///Output open-drain
            open_drain = 1,
        } = .push_pull,
        _unused16: u16 = 0,
    };
    ///GPIO port output type register
    pub const otyper = Register(otyper_val).init(0x48000000 + 0x4);

    //////////////////////////
    ///OSPEEDR
    const ospeedr_val = packed struct {
        ///OSPEEDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr0: u2 = 0,
        ///OSPEEDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr1: u2 = 0,
        ///OSPEEDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr2: u2 = 0,
        ///OSPEEDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr3: u2 = 0,
        ///OSPEEDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr4: u2 = 0,
        ///OSPEEDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr5: u2 = 0,
        ///OSPEEDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr6: u2 = 0,
        ///OSPEEDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr7: u2 = 0,
        ///OSPEEDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr8: u2 = 0,
        ///OSPEEDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr9: u2 = 0,
        ///OSPEEDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr10: u2 = 0,
        ///OSPEEDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr11: u2 = 0,
        ///OSPEEDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr12: u2 = 0,
        ///OSPEEDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr13: u2 = 0,
        ///OSPEEDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr14: u2 = 0,
        ///OSPEEDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        ospeedr15: packed enum(u2) {
            ///Low speed
            low_speed = 0,
            ///Medium speed
            medium_speed = 1,
            ///High speed
            high_speed = 2,
            ///Very high speed
            very_high_speed = 3,
        } = .low_speed,
    };
    ///GPIO port output speed
    ///register
    pub const ospeedr = Register(ospeedr_val).init(0x48000000 + 0x8);

    //////////////////////////
    ///PUPDR
    const pupdr_val = packed struct {
        ///PUPDR0 [0:1]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr0: u2 = 0,
        ///PUPDR1 [2:3]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr1: u2 = 0,
        ///PUPDR2 [4:5]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr2: u2 = 0,
        ///PUPDR3 [6:7]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr3: u2 = 0,
        ///PUPDR4 [8:9]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr4: u2 = 0,
        ///PUPDR5 [10:11]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr5: u2 = 0,
        ///PUPDR6 [12:13]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr6: u2 = 0,
        ///PUPDR7 [14:15]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr7: u2 = 0,
        ///PUPDR8 [16:17]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr8: u2 = 0,
        ///PUPDR9 [18:19]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr9: u2 = 0,
        ///PUPDR10 [20:21]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr10: u2 = 0,
        ///PUPDR11 [22:23]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr11: u2 = 0,
        ///PUPDR12 [24:25]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr12: u2 = 0,
        ///PUPDR13 [26:27]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr13: u2 = 1,
        ///PUPDR14 [28:29]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr14: u2 = 2,
        ///PUPDR15 [30:31]
        ///Port x configuration bits (y =
        ///0..15)
        pupdr15: packed enum(u2) {
            ///No pull-up, pull-down
            floating = 0,
            ///Pull-up
            pull_up = 1,
            ///Pull-down
            pull_down = 2,
        } = .floating,
    };
    ///GPIO port pull-up/pull-down
    ///register
    pub const pupdr = Register(pupdr_val).init(0x48000000 + 0xC);

    //////////////////////////
    ///IDR
    const idr_val = packed struct {
        ///IDR0 [0:0]
        ///Port input data (y =
        ///0..15)
        idr0: u1 = 0,
        ///IDR1 [1:1]
        ///Port input data (y =
        ///0..15)
        idr1: u1 = 0,
        ///IDR2 [2:2]
        ///Port input data (y =
        ///0..15)
        idr2: u1 = 0,
        ///IDR3 [3:3]
        ///Port input data (y =
        ///0..15)
        idr3: u1 = 0,
        ///IDR4 [4:4]
        ///Port input data (y =
        ///0..15)
        idr4: u1 = 0,
        ///IDR5 [5:5]
        ///Port input data (y =
        ///0..15)
        idr5: u1 = 0,
        ///IDR6 [6:6]
        ///Port input data (y =
        ///0..15)
        idr6: u1 = 0,
        ///IDR7 [7:7]
        ///Port input data (y =
        ///0..15)
        idr7: u1 = 0,
        ///IDR8 [8:8]
        ///Port input data (y =
        ///0..15)
        idr8: u1 = 0,
        ///IDR9 [9:9]
        ///Port input data (y =
        ///0..15)
        idr9: u1 = 0,
        ///IDR10 [10:10]
        ///Port input data (y =
        ///0..15)
        idr10: u1 = 0,
        ///IDR11 [11:11]
        ///Port input data (y =
        ///0..15)
        idr11: u1 = 0,
        ///IDR12 [12:12]
        ///Port input data (y =
        ///0..15)
        idr12: u1 = 0,
        ///IDR13 [13:13]
        ///Port input data (y =
        ///0..15)
        idr13: u1 = 0,
        ///IDR14 [14:14]
        ///Port input data (y =
        ///0..15)
        idr14: u1 = 0,
        ///IDR15 [15:15]
        ///Port input data (y =
        ///0..15)
        idr15: packed enum(u1) {
            ///Input is logic high
            high = 1,
            ///Input is logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port input data register
    pub const idr = RegisterRW(idr_val, void).init(0x48000000 + 0x10);

    //////////////////////////
    ///ODR
    const odr_val = packed struct {
        ///ODR0 [0:0]
        ///Port output data (y =
        ///0..15)
        odr0: u1 = 0,
        ///ODR1 [1:1]
        ///Port output data (y =
        ///0..15)
        odr1: u1 = 0,
        ///ODR2 [2:2]
        ///Port output data (y =
        ///0..15)
        odr2: u1 = 0,
        ///ODR3 [3:3]
        ///Port output data (y =
        ///0..15)
        odr3: u1 = 0,
        ///ODR4 [4:4]
        ///Port output data (y =
        ///0..15)
        odr4: u1 = 0,
        ///ODR5 [5:5]
        ///Port output data (y =
        ///0..15)
        odr5: u1 = 0,
        ///ODR6 [6:6]
        ///Port output data (y =
        ///0..15)
        odr6: u1 = 0,
        ///ODR7 [7:7]
        ///Port output data (y =
        ///0..15)
        odr7: u1 = 0,
        ///ODR8 [8:8]
        ///Port output data (y =
        ///0..15)
        odr8: u1 = 0,
        ///ODR9 [9:9]
        ///Port output data (y =
        ///0..15)
        odr9: u1 = 0,
        ///ODR10 [10:10]
        ///Port output data (y =
        ///0..15)
        odr10: u1 = 0,
        ///ODR11 [11:11]
        ///Port output data (y =
        ///0..15)
        odr11: u1 = 0,
        ///ODR12 [12:12]
        ///Port output data (y =
        ///0..15)
        odr12: u1 = 0,
        ///ODR13 [13:13]
        ///Port output data (y =
        ///0..15)
        odr13: u1 = 0,
        ///ODR14 [14:14]
        ///Port output data (y =
        ///0..15)
        odr14: u1 = 0,
        ///ODR15 [15:15]
        ///Port output data (y =
        ///0..15)
        odr15: packed enum(u1) {
            ///Set output to logic high
            high = 1,
            ///Set output to logic low
            low = 0,
        } = .low,
        _unused16: u16 = 0,
    };
    ///GPIO port output data register
    pub const odr = Register(odr_val).init(0x48000000 + 0x14);

    //////////////////////////
    ///BSRR
    const bsrr_val = packed struct {
        ///BS0 [0:0]
        ///Port x set bit y (y=
        ///0..15)
        bs0: u1 = 0,
        ///BS1 [1:1]
        ///Port x set bit y (y=
        ///0..15)
        bs1: u1 = 0,
        ///BS2 [2:2]
        ///Port x set bit y (y=
        ///0..15)
        bs2: u1 = 0,
        ///BS3 [3:3]
        ///Port x set bit y (y=
        ///0..15)
        bs3: u1 = 0,
        ///BS4 [4:4]
        ///Port x set bit y (y=
        ///0..15)
        bs4: u1 = 0,
        ///BS5 [5:5]
        ///Port x set bit y (y=
        ///0..15)
        bs5: u1 = 0,
        ///BS6 [6:6]
        ///Port x set bit y (y=
        ///0..15)
        bs6: u1 = 0,
        ///BS7 [7:7]
        ///Port x set bit y (y=
        ///0..15)
        bs7: u1 = 0,
        ///BS8 [8:8]
        ///Port x set bit y (y=
        ///0..15)
        bs8: u1 = 0,
        ///BS9 [9:9]
        ///Port x set bit y (y=
        ///0..15)
        bs9: u1 = 0,
        ///BS10 [10:10]
        ///Port x set bit y (y=
        ///0..15)
        bs10: u1 = 0,
        ///BS11 [11:11]
        ///Port x set bit y (y=
        ///0..15)
        bs11: u1 = 0,
        ///BS12 [12:12]
        ///Port x set bit y (y=
        ///0..15)
        bs12: u1 = 0,
        ///BS13 [13:13]
        ///Port x set bit y (y=
        ///0..15)
        bs13: u1 = 0,
        ///BS14 [14:14]
        ///Port x set bit y (y=
        ///0..15)
        bs14: u1 = 0,
        ///BS15 [15:15]
        ///Port x set bit y (y=
        ///0..15)
        bs15: u1 = 0,
        ///BR0 [16:16]
        ///Port x set bit y (y=
        ///0..15)
        br0: u1 = 0,
        ///BR1 [17:17]
        ///Port x reset bit y (y =
        ///0..15)
        br1: u1 = 0,
        ///BR2 [18:18]
        ///Port x reset bit y (y =
        ///0..15)
        br2: u1 = 0,
        ///BR3 [19:19]
        ///Port x reset bit y (y =
        ///0..15)
        br3: u1 = 0,
        ///BR4 [20:20]
        ///Port x reset bit y (y =
        ///0..15)
        br4: u1 = 0,
        ///BR5 [21:21]
        ///Port x reset bit y (y =
        ///0..15)
        br5: u1 = 0,
        ///BR6 [22:22]
        ///Port x reset bit y (y =
        ///0..15)
        br6: u1 = 0,
        ///BR7 [23:23]
        ///Port x reset bit y (y =
        ///0..15)
        br7: u1 = 0,
        ///BR8 [24:24]
        ///Port x reset bit y (y =
        ///0..15)
        br8: u1 = 0,
        ///BR9 [25:25]
        ///Port x reset bit y (y =
        ///0..15)
        br9: u1 = 0,
        ///BR10 [26:26]
        ///Port x reset bit y (y =
        ///0..15)
        br10: u1 = 0,
        ///BR11 [27:27]
        ///Port x reset bit y (y =
        ///0..15)
        br11: u1 = 0,
        ///BR12 [28:28]
        ///Port x reset bit y (y =
        ///0..15)
        br12: u1 = 0,
        ///BR13 [29:29]
        ///Port x reset bit y (y =
        ///0..15)
        br13: u1 = 0,
        ///BR14 [30:30]
        ///Port x reset bit y (y =
        ///0..15)
        br14: u1 = 0,
        ///BR15 [31:31]
        ///Port x reset bit y (y =
        ///0..15)
        br15: u1 = 0,
    };
    ///GPIO port bit set/reset
    ///register
    pub const bsrr = RegisterRW(void, bsrr_val).init(0x48000000 + 0x18);

    //////////////////////////
    ///LCKR
    const lckr_val = packed struct {
        ///LCK0 [0:0]
        ///Port x lock bit y (y=
        ///0..15)
        lck0: u1 = 0,
        ///LCK1 [1:1]
        ///Port x lock bit y (y=
        ///0..15)
        lck1: u1 = 0,
        ///LCK2 [2:2]
        ///Port x lock bit y (y=
        ///0..15)
        lck2: u1 = 0,
        ///LCK3 [3:3]
        ///Port x lock bit y (y=
        ///0..15)
        lck3: u1 = 0,
        ///LCK4 [4:4]
        ///Port x lock bit y (y=
        ///0..15)
        lck4: u1 = 0,
        ///LCK5 [5:5]
        ///Port x lock bit y (y=
        ///0..15)
        lck5: u1 = 0,
        ///LCK6 [6:6]
        ///Port x lock bit y (y=
        ///0..15)
        lck6: u1 = 0,
        ///LCK7 [7:7]
        ///Port x lock bit y (y=
        ///0..15)
        lck7: u1 = 0,
        ///LCK8 [8:8]
        ///Port x lock bit y (y=
        ///0..15)
        lck8: u1 = 0,
        ///LCK9 [9:9]
        ///Port x lock bit y (y=
        ///0..15)
        lck9: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCK10 [10:10]
        ///Port x lock bit y (y=
        ///0..15)
        lck10: u1 = 0,
        ///LCK11 [11:11]
        ///Port x lock bit y (y=
        ///0..15)
        lck11: u1 = 0,
        ///LCK12 [12:12]
        ///Port x lock bit y (y=
        ///0..15)
        lck12: u1 = 0,
        ///LCK13 [13:13]
        ///Port x lock bit y (y=
        ///0..15)
        lck13: u1 = 0,
        ///LCK14 [14:14]
        ///Port x lock bit y (y=
        ///0..15)
        lck14: u1 = 0,
        ///LCK15 [15:15]
        ///Port x lock bit y (y=
        ///0..15)
        lck15: packed enum(u1) {
            ///Port configuration not locked
            unlocked = 0,
            ///Port configuration locked
            locked = 1,
        } = .unlocked,
        ///LCKK [16:16]
        ///Port x lock bit y (y=
        ///0..15)
        lckk: packed enum(u1) {
            ///Port configuration lock key not active
            not_active = 0,
            ///Port configuration lock key active
            active = 1,
        } = .not_active,
        _unused17: u15 = 0,
    };
    ///GPIO port configuration lock
    ///register
    pub const lckr = Register(lckr_val).init(0x48000000 + 0x1C);

    //////////////////////////
    ///AFRL
    const afrl_val = packed struct {
        ///AFRL0 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl0: u4 = 0,
        ///AFRL1 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl1: u4 = 0,
        ///AFRL2 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl2: u4 = 0,
        ///AFRL3 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl3: u4 = 0,
        ///AFRL4 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl4: u4 = 0,
        ///AFRL5 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl5: u4 = 0,
        ///AFRL6 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl6: u4 = 0,
        ///AFRL7 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 0..7)
        afrl7: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function low
    ///register
    pub const afrl = Register(afrl_val).init(0x48000000 + 0x20);

    //////////////////////////
    ///AFRH
    const afrh_val = packed struct {
        ///AFRH8 [0:3]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh8: u4 = 0,
        ///AFRH9 [4:7]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh9: u4 = 0,
        ///AFRH10 [8:11]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh10: u4 = 0,
        ///AFRH11 [12:15]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh11: u4 = 0,
        ///AFRH12 [16:19]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh12: u4 = 0,
        ///AFRH13 [20:23]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh13: u4 = 0,
        ///AFRH14 [24:27]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh14: u4 = 0,
        ///AFRH15 [28:31]
        ///Alternate function selection for port x
        ///bit y (y = 8..15)
        afrh15: packed enum(u4) {
            ///AF0
            af0 = 0,
            ///AF1
            af1 = 1,
            ///AF2
            af2 = 2,
            ///AF3
            af3 = 3,
            ///AF4
            af4 = 4,
            ///AF5
            af5 = 5,
            ///AF6
            af6 = 6,
            ///AF7
            af7 = 7,
            ///AF8
            af8 = 8,
            ///AF9
            af9 = 9,
            ///AF10
            af10 = 10,
            ///AF11
            af11 = 11,
            ///AF12
            af12 = 12,
            ///AF13
            af13 = 13,
            ///AF14
            af14 = 14,
            ///AF15
            af15 = 15,
        } = .af0,
    };
    ///GPIO alternate function high
    ///register
    pub const afrh = Register(afrh_val).init(0x48000000 + 0x24);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BR0 [0:0]
        ///Port x Reset bit y
        br0: u1 = 0,
        ///BR1 [1:1]
        ///Port x Reset bit y
        br1: u1 = 0,
        ///BR2 [2:2]
        ///Port x Reset bit y
        br2: u1 = 0,
        ///BR3 [3:3]
        ///Port x Reset bit y
        br3: u1 = 0,
        ///BR4 [4:4]
        ///Port x Reset bit y
        br4: u1 = 0,
        ///BR5 [5:5]
        ///Port x Reset bit y
        br5: u1 = 0,
        ///BR6 [6:6]
        ///Port x Reset bit y
        br6: u1 = 0,
        ///BR7 [7:7]
        ///Port x Reset bit y
        br7: u1 = 0,
        ///BR8 [8:8]
        ///Port x Reset bit y
        br8: u1 = 0,
        ///BR9 [9:9]
        ///Port x Reset bit y
        br9: u1 = 0,
        ///BR10 [10:10]
        ///Port x Reset bit y
        br10: u1 = 0,
        ///BR11 [11:11]
        ///Port x Reset bit y
        br11: u1 = 0,
        ///BR12 [12:12]
        ///Port x Reset bit y
        br12: u1 = 0,
        ///BR13 [13:13]
        ///Port x Reset bit y
        br13: u1 = 0,
        ///BR14 [14:14]
        ///Port x Reset bit y
        br14: u1 = 0,
        ///BR15 [15:15]
        ///Port x Reset bit y
        br15: u1 = 0,
        _unused16: u16 = 0,
    };
    ///Port bit reset register
    pub const brr = RegisterRW(void, brr_val).init(0x48000000 + 0x28);
};

///Serial peripheral interface
pub const spi1 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CPHA [0:0]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first_edge = 0,
            ///The second clock transition is the first data capture edge
            second_edge = 1,
        } = .first_edge,
        ///CPOL [1:1]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///CK to 0 when idle
            idle_low = 0,
            ///CK to 1 when idle
            idle_high = 1,
        } = .idle_low,
        ///MSTR [2:2]
        ///Master selection
        mstr: packed enum(u1) {
            ///Slave configuration
            slave = 0,
            ///Master configuration
            master = 1,
        } = .slave,
        ///BR [3:5]
        ///Baud rate control
        br: packed enum(u3) {
            ///f_PCLK / 2
            div2 = 0,
            ///f_PCLK / 4
            div4 = 1,
            ///f_PCLK / 8
            div8 = 2,
            ///f_PCLK / 16
            div16 = 3,
            ///f_PCLK / 32
            div32 = 4,
            ///f_PCLK / 64
            div64 = 5,
            ///f_PCLK / 128
            div128 = 6,
            ///f_PCLK / 256
            div256 = 7,
        } = .div2,
        ///SPE [6:6]
        ///SPI enable
        spe: packed enum(u1) {
            ///Peripheral disabled
            disabled = 0,
            ///Peripheral enabled
            enabled = 1,
        } = .disabled,
        ///LSBFIRST [7:7]
        ///Frame format
        lsbfirst: packed enum(u1) {
            ///Data is transmitted/received with the MSB first
            msbfirst = 0,
            ///Data is transmitted/received with the LSB first
            lsbfirst = 1,
        } = .msbfirst,
        ///SSI [8:8]
        ///Internal slave select
        ssi: packed enum(u1) {
            ///0 is forced onto the NSS pin and the I/O value of the NSS pin is ignored
            slave_selected = 0,
            ///1 is forced onto the NSS pin and the I/O value of the NSS pin is ignored
            slave_not_selected = 1,
        } = .slave_selected,
        ///SSM [9:9]
        ///Software slave management
        ssm: packed enum(u1) {
            ///Software slave management disabled
            disabled = 0,
            ///Software slave management enabled
            enabled = 1,
        } = .disabled,
        ///RXONLY [10:10]
        ///Receive only
        rxonly: packed enum(u1) {
            ///Full duplex (Transmit and receive)
            full_duplex = 0,
            ///Output disabled (Receive-only mode)
            output_disabled = 1,
        } = .full_duplex,
        ///CRCL [11:11]
        ///CRC length
        crcl: packed enum(u1) {
            ///8-bit CRC length
            eight_bit = 0,
            ///16-bit CRC length
            sixteen_bit = 1,
        } = .eight_bit,
        ///CRCNEXT [12:12]
        ///CRC transfer next
        crcnext: packed enum(u1) {
            ///Next transmit value is from Tx buffer
            tx_buffer = 0,
            ///Next transmit value is from Tx CRC register
            crc = 1,
        } = .tx_buffer,
        ///CRCEN [13:13]
        ///Hardware CRC calculation
        ///enable
        crcen: packed enum(u1) {
            ///CRC calculation disabled
            disabled = 0,
            ///CRC calculation enabled
            enabled = 1,
        } = .disabled,
        ///BIDIOE [14:14]
        ///Output enable in bidirectional
        ///mode
        bidioe: packed enum(u1) {
            ///Output disabled (receive-only mode)
            output_disabled = 0,
            ///Output enabled (transmit-only mode)
            output_enabled = 1,
        } = .output_disabled,
        ///BIDIMODE [15:15]
        ///Bidirectional data mode
        ///enable
        bidimode: packed enum(u1) {
            ///2-line unidirectional data mode selected
            unidirectional = 0,
            ///1-line bidirectional data mode selected
            bidirectional = 1,
        } = .unidirectional,
        _unused16: u16 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40013000 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///RXDMAEN [0:0]
        ///Rx buffer DMA enable
        rxdmaen: packed enum(u1) {
            ///Rx buffer DMA disabled
            disabled = 0,
            ///Rx buffer DMA enabled
            enabled = 1,
        } = .disabled,
        ///TXDMAEN [1:1]
        ///Tx buffer DMA enable
        txdmaen: packed enum(u1) {
            ///Tx buffer DMA disabled
            disabled = 0,
            ///Tx buffer DMA enabled
            enabled = 1,
        } = .disabled,
        ///SSOE [2:2]
        ///SS output enable
        ssoe: packed enum(u1) {
            ///SS output is disabled in master mode
            disabled = 0,
            ///SS output is enabled in master mode
            enabled = 1,
        } = .disabled,
        ///NSSP [3:3]
        ///NSS pulse management
        nssp: packed enum(u1) {
            ///No NSS pulse
            no_pulse = 0,
            ///NSS pulse generated
            pulse_generated = 1,
        } = .no_pulse,
        ///FRF [4:4]
        ///Frame format
        frf: packed enum(u1) {
            ///SPI Motorola mode
            motorola = 0,
            ///SPI TI mode
            ti = 1,
        } = .motorola,
        ///ERRIE [5:5]
        ///Error interrupt enable
        errie: packed enum(u1) {
            ///Error interrupt masked
            masked = 0,
            ///Error interrupt not masked
            not_masked = 1,
        } = .masked,
        ///RXNEIE [6:6]
        ///RX buffer not empty interrupt
        ///enable
        rxneie: packed enum(u1) {
            ///RXE interrupt masked
            masked = 0,
            ///RXE interrupt not masked
            not_masked = 1,
        } = .masked,
        ///TXEIE [7:7]
        ///Tx buffer empty interrupt
        ///enable
        txeie: packed enum(u1) {
            ///TXE interrupt masked
            masked = 0,
            ///TXE interrupt not masked
            not_masked = 1,
        } = .masked,
        ///DS [8:11]
        ///Data size
        ds: packed enum(u4) {
            ///4-bit
            four_bit = 3,
            ///5-bit
            five_bit = 4,
            ///6-bit
            six_bit = 5,
            ///7-bit
            seven_bit = 6,
            ///8-bit
            eight_bit = 7,
            ///9-bit
            nine_bit = 8,
            ///10-bit
            ten_bit = 9,
            ///11-bit
            eleven_bit = 10,
            ///12-bit
            twelve_bit = 11,
            ///13-bit
            thirteen_bit = 12,
            ///14-bit
            fourteen_bit = 13,
            ///15-bit
            fifteen_bit = 14,
            ///16-bit
            sixteen_bit = 15,
            _zero = 0,
        } = ._zero,
        ///FRXTH [12:12]
        ///FIFO reception threshold
        frxth: packed enum(u1) {
            ///RXNE event is generated if the FIFO level is greater than or equal to 1/2 (16-bit)
            half = 0,
            ///RXNE event is generated if the FIFO level is greater than or equal to 1/4 (8-bit)
            quarter = 1,
        } = .half,
        ///LDMA_RX [13:13]
        ///Last DMA transfer for
        ///reception
        ldma_rx: packed enum(u1) {
            ///Number of data to transfer for receive is even
            even = 0,
            ///Number of data to transfer for receive is odd
            odd = 1,
        } = .even,
        ///LDMA_TX [14:14]
        ///Last DMA transfer for
        ///transmission
        ldma_tx: packed enum(u1) {
            ///Number of data to transfer for transmit is even
            even = 0,
            ///Number of data to transfer for transmit is odd
            odd = 1,
        } = .even,
        _unused15: u17 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40013000 + 0x4);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///RXNE [0:0]
        ///Receive buffer not empty
        rxne: u1 = 0,
        ///TXE [1:1]
        ///Transmit buffer empty
        txe: u1 = 1,
        _unused2: u2 = 0,
        ///CRCERR [4:4]
        ///CRC error flag
        crcerr: u1 = 0,
        ///MODF [5:5]
        ///Mode fault
        modf: packed enum(u1) {
            ///No mode fault occurred
            no_fault = 0,
            ///Mode fault occurred
            fault = 1,
        } = .no_fault,
        ///OVR [6:6]
        ///Overrun flag
        ovr: packed enum(u1) {
            ///No overrun occurred
            no_overrun = 0,
            ///Overrun occurred
            overrun = 1,
        } = .no_overrun,
        ///BSY [7:7]
        ///Busy flag
        bsy: packed enum(u1) {
            ///SPI not busy
            not_busy = 0,
            ///SPI busy
            busy = 1,
        } = .not_busy,
        ///FRE [8:8]
        ///Frame format error
        fre: packed enum(u1) {
            ///No frame format error
            no_error = 0,
            ///A frame format error occurred
            _error = 1,
        } = .no_error,
        ///FRLVL [9:10]
        ///FIFO reception level
        frlvl: packed enum(u2) {
            ///Rx FIFO Empty
            empty = 0,
            ///Rx 1/4 FIFO
            quarter = 1,
            ///Rx 1/2 FIFO
            half = 2,
            ///Rx FIFO full
            full = 3,
        } = .empty,
        ///FTLVL [11:12]
        ///FIFO transmission level
        ftlvl: packed enum(u2) {
            ///Tx FIFO Empty
            empty = 0,
            ///Tx 1/4 FIFO
            quarter = 1,
            ///Tx 1/2 FIFO
            half = 2,
            ///Tx FIFO full
            full = 3,
        } = .empty,
        _unused13: u19 = 0,
    };
    const sr_val_write = packed struct {
        ///RXNE [0:0]
        ///Receive buffer not empty
        rxne: u1 = 0,
        ///TXE [1:1]
        ///Transmit buffer empty
        txe: u1 = 1,
        _unused2: u2 = 0,
        ///CRCERR [4:4]
        ///CRC error flag
        crcerr: u1 = 0,
        ///MODF [5:5]
        ///Mode fault
        modf: u1 = 0,
        ///OVR [6:6]
        ///Overrun flag
        ovr: u1 = 0,
        ///BSY [7:7]
        ///Busy flag
        bsy: u1 = 0,
        ///FRE [8:8]
        ///Frame format error
        fre: u1 = 0,
        ///FRLVL [9:10]
        ///FIFO reception level
        frlvl: u2 = 0,
        ///FTLVL [11:12]
        ///FIFO transmission level
        ftlvl: u2 = 0,
        _unused13: u19 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40013000 + 0x8);

    //////////////////////////
    ///DR
    const dr_val = packed struct {
        ///DR [0:15]
        ///Data register
        dr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///data register
    pub const dr = Register(dr_val).init(0x40013000 + 0xC);

    //////////////////////////
    ///CRCPR
    const crcpr_val = packed struct {
        ///CRCPOLY [0:15]
        ///CRC polynomial register
        crcpoly: u16 = 7,
        _unused16: u16 = 0,
    };
    ///CRC polynomial register
    pub const crcpr = Register(crcpr_val).init(0x40013000 + 0x10);

    //////////////////////////
    ///RXCRCR
    const rxcrcr_val = packed struct {
        ///RxCRC [0:15]
        ///Rx CRC register
        rx_crc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///RX CRC register
    pub const rxcrcr = RegisterRW(rxcrcr_val, void).init(0x40013000 + 0x14);

    //////////////////////////
    ///TXCRCR
    const txcrcr_val = packed struct {
        ///TxCRC [0:15]
        ///Tx CRC register
        tx_crc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///TX CRC register
    pub const txcrcr = RegisterRW(txcrcr_val, void).init(0x40013000 + 0x18);

    //////////////////////////
    ///I2SCFGR
    const i2scfgr_val = packed struct {
        ///CHLEN [0:0]
        ///Channel length (number of bits per audio
        ///channel)
        chlen: packed enum(u1) {
            ///16-bit wide
            sixteen_bit = 0,
            ///32-bit wide
            thirty_two_bit = 1,
        } = .sixteen_bit,
        ///DATLEN [1:2]
        ///Data length to be
        ///transferred
        datlen: packed enum(u2) {
            ///16-bit data length
            sixteen_bit = 0,
            ///24-bit data length
            twenty_four_bit = 1,
            ///32-bit data length
            thirty_two_bit = 2,
        } = .sixteen_bit,
        ///CKPOL [3:3]
        ///Steady state clock
        ///polarity
        ckpol: packed enum(u1) {
            ///I2S clock inactive state is low level
            idle_low = 0,
            ///I2S clock inactive state is high level
            idle_high = 1,
        } = .idle_low,
        ///I2SSTD [4:5]
        ///I2S standard selection
        i2sstd: packed enum(u2) {
            ///I2S Philips standard
            philips = 0,
            ///MSB justified standard
            msb = 1,
            ///LSB justified standard
            lsb = 2,
            ///PCM standard
            pcm = 3,
        } = .philips,
        _unused6: u1 = 0,
        ///PCMSYNC [7:7]
        ///PCM frame synchronization
        pcmsync: packed enum(u1) {
            ///Short frame synchronisation
            short = 0,
            ///Long frame synchronisation
            long = 1,
        } = .short,
        ///I2SCFG [8:9]
        ///I2S configuration mode
        i2scfg: packed enum(u2) {
            ///Slave - transmit
            slave_tx = 0,
            ///Slave - receive
            slave_rx = 1,
            ///Master - transmit
            master_tx = 2,
            ///Master - receive
            master_rx = 3,
        } = .slave_tx,
        ///I2SE [10:10]
        ///I2S Enable
        i2se: packed enum(u1) {
            ///I2S peripheral is disabled
            disabled = 0,
            ///I2S peripheral is enabled
            enabled = 1,
        } = .disabled,
        ///I2SMOD [11:11]
        ///I2S mode selection
        i2smod: packed enum(u1) {
            ///SPI mode is selected
            spimode = 0,
            ///I2S mode is selected
            i2smode = 1,
        } = .spimode,
        _unused12: u20 = 0,
    };
    ///I2S configuration register
    pub const i2scfgr = Register(i2scfgr_val).init(0x40013000 + 0x1C);

    //////////////////////////
    ///I2SPR
    const i2spr_val = packed struct {
        ///I2SDIV [0:7]
        ///I2S Linear prescaler
        i2sdiv: u8 = 16,
        ///ODD [8:8]
        ///Odd factor for the
        ///prescaler
        odd: packed enum(u1) {
            ///Real divider value is I2SDIV * 2
            even = 0,
            ///Real divider value is (I2SDIV * 2) + 1
            odd = 1,
        } = .even,
        ///MCKOE [9:9]
        ///Master clock output enable
        mckoe: packed enum(u1) {
            ///Master clock output is disabled
            disabled = 0,
            ///Master clock output is enabled
            enabled = 1,
        } = .disabled,
        _unused10: u22 = 0,
    };
    ///I2S prescaler register
    pub const i2spr = Register(i2spr_val).init(0x40013000 + 0x20);
};

///Serial peripheral interface
pub const spi2 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CPHA [0:0]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first_edge = 0,
            ///The second clock transition is the first data capture edge
            second_edge = 1,
        } = .first_edge,
        ///CPOL [1:1]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///CK to 0 when idle
            idle_low = 0,
            ///CK to 1 when idle
            idle_high = 1,
        } = .idle_low,
        ///MSTR [2:2]
        ///Master selection
        mstr: packed enum(u1) {
            ///Slave configuration
            slave = 0,
            ///Master configuration
            master = 1,
        } = .slave,
        ///BR [3:5]
        ///Baud rate control
        br: packed enum(u3) {
            ///f_PCLK / 2
            div2 = 0,
            ///f_PCLK / 4
            div4 = 1,
            ///f_PCLK / 8
            div8 = 2,
            ///f_PCLK / 16
            div16 = 3,
            ///f_PCLK / 32
            div32 = 4,
            ///f_PCLK / 64
            div64 = 5,
            ///f_PCLK / 128
            div128 = 6,
            ///f_PCLK / 256
            div256 = 7,
        } = .div2,
        ///SPE [6:6]
        ///SPI enable
        spe: packed enum(u1) {
            ///Peripheral disabled
            disabled = 0,
            ///Peripheral enabled
            enabled = 1,
        } = .disabled,
        ///LSBFIRST [7:7]
        ///Frame format
        lsbfirst: packed enum(u1) {
            ///Data is transmitted/received with the MSB first
            msbfirst = 0,
            ///Data is transmitted/received with the LSB first
            lsbfirst = 1,
        } = .msbfirst,
        ///SSI [8:8]
        ///Internal slave select
        ssi: packed enum(u1) {
            ///0 is forced onto the NSS pin and the I/O value of the NSS pin is ignored
            slave_selected = 0,
            ///1 is forced onto the NSS pin and the I/O value of the NSS pin is ignored
            slave_not_selected = 1,
        } = .slave_selected,
        ///SSM [9:9]
        ///Software slave management
        ssm: packed enum(u1) {
            ///Software slave management disabled
            disabled = 0,
            ///Software slave management enabled
            enabled = 1,
        } = .disabled,
        ///RXONLY [10:10]
        ///Receive only
        rxonly: packed enum(u1) {
            ///Full duplex (Transmit and receive)
            full_duplex = 0,
            ///Output disabled (Receive-only mode)
            output_disabled = 1,
        } = .full_duplex,
        ///CRCL [11:11]
        ///CRC length
        crcl: packed enum(u1) {
            ///8-bit CRC length
            eight_bit = 0,
            ///16-bit CRC length
            sixteen_bit = 1,
        } = .eight_bit,
        ///CRCNEXT [12:12]
        ///CRC transfer next
        crcnext: packed enum(u1) {
            ///Next transmit value is from Tx buffer
            tx_buffer = 0,
            ///Next transmit value is from Tx CRC register
            crc = 1,
        } = .tx_buffer,
        ///CRCEN [13:13]
        ///Hardware CRC calculation
        ///enable
        crcen: packed enum(u1) {
            ///CRC calculation disabled
            disabled = 0,
            ///CRC calculation enabled
            enabled = 1,
        } = .disabled,
        ///BIDIOE [14:14]
        ///Output enable in bidirectional
        ///mode
        bidioe: packed enum(u1) {
            ///Output disabled (receive-only mode)
            output_disabled = 0,
            ///Output enabled (transmit-only mode)
            output_enabled = 1,
        } = .output_disabled,
        ///BIDIMODE [15:15]
        ///Bidirectional data mode
        ///enable
        bidimode: packed enum(u1) {
            ///2-line unidirectional data mode selected
            unidirectional = 0,
            ///1-line bidirectional data mode selected
            bidirectional = 1,
        } = .unidirectional,
        _unused16: u16 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40003800 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///RXDMAEN [0:0]
        ///Rx buffer DMA enable
        rxdmaen: packed enum(u1) {
            ///Rx buffer DMA disabled
            disabled = 0,
            ///Rx buffer DMA enabled
            enabled = 1,
        } = .disabled,
        ///TXDMAEN [1:1]
        ///Tx buffer DMA enable
        txdmaen: packed enum(u1) {
            ///Tx buffer DMA disabled
            disabled = 0,
            ///Tx buffer DMA enabled
            enabled = 1,
        } = .disabled,
        ///SSOE [2:2]
        ///SS output enable
        ssoe: packed enum(u1) {
            ///SS output is disabled in master mode
            disabled = 0,
            ///SS output is enabled in master mode
            enabled = 1,
        } = .disabled,
        ///NSSP [3:3]
        ///NSS pulse management
        nssp: packed enum(u1) {
            ///No NSS pulse
            no_pulse = 0,
            ///NSS pulse generated
            pulse_generated = 1,
        } = .no_pulse,
        ///FRF [4:4]
        ///Frame format
        frf: packed enum(u1) {
            ///SPI Motorola mode
            motorola = 0,
            ///SPI TI mode
            ti = 1,
        } = .motorola,
        ///ERRIE [5:5]
        ///Error interrupt enable
        errie: packed enum(u1) {
            ///Error interrupt masked
            masked = 0,
            ///Error interrupt not masked
            not_masked = 1,
        } = .masked,
        ///RXNEIE [6:6]
        ///RX buffer not empty interrupt
        ///enable
        rxneie: packed enum(u1) {
            ///RXE interrupt masked
            masked = 0,
            ///RXE interrupt not masked
            not_masked = 1,
        } = .masked,
        ///TXEIE [7:7]
        ///Tx buffer empty interrupt
        ///enable
        txeie: packed enum(u1) {
            ///TXE interrupt masked
            masked = 0,
            ///TXE interrupt not masked
            not_masked = 1,
        } = .masked,
        ///DS [8:11]
        ///Data size
        ds: packed enum(u4) {
            ///4-bit
            four_bit = 3,
            ///5-bit
            five_bit = 4,
            ///6-bit
            six_bit = 5,
            ///7-bit
            seven_bit = 6,
            ///8-bit
            eight_bit = 7,
            ///9-bit
            nine_bit = 8,
            ///10-bit
            ten_bit = 9,
            ///11-bit
            eleven_bit = 10,
            ///12-bit
            twelve_bit = 11,
            ///13-bit
            thirteen_bit = 12,
            ///14-bit
            fourteen_bit = 13,
            ///15-bit
            fifteen_bit = 14,
            ///16-bit
            sixteen_bit = 15,
            _zero = 0,
        } = ._zero,
        ///FRXTH [12:12]
        ///FIFO reception threshold
        frxth: packed enum(u1) {
            ///RXNE event is generated if the FIFO level is greater than or equal to 1/2 (16-bit)
            half = 0,
            ///RXNE event is generated if the FIFO level is greater than or equal to 1/4 (8-bit)
            quarter = 1,
        } = .half,
        ///LDMA_RX [13:13]
        ///Last DMA transfer for
        ///reception
        ldma_rx: packed enum(u1) {
            ///Number of data to transfer for receive is even
            even = 0,
            ///Number of data to transfer for receive is odd
            odd = 1,
        } = .even,
        ///LDMA_TX [14:14]
        ///Last DMA transfer for
        ///transmission
        ldma_tx: packed enum(u1) {
            ///Number of data to transfer for transmit is even
            even = 0,
            ///Number of data to transfer for transmit is odd
            odd = 1,
        } = .even,
        _unused15: u17 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40003800 + 0x4);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///RXNE [0:0]
        ///Receive buffer not empty
        rxne: u1 = 0,
        ///TXE [1:1]
        ///Transmit buffer empty
        txe: u1 = 1,
        _unused2: u2 = 0,
        ///CRCERR [4:4]
        ///CRC error flag
        crcerr: u1 = 0,
        ///MODF [5:5]
        ///Mode fault
        modf: packed enum(u1) {
            ///No mode fault occurred
            no_fault = 0,
            ///Mode fault occurred
            fault = 1,
        } = .no_fault,
        ///OVR [6:6]
        ///Overrun flag
        ovr: packed enum(u1) {
            ///No overrun occurred
            no_overrun = 0,
            ///Overrun occurred
            overrun = 1,
        } = .no_overrun,
        ///BSY [7:7]
        ///Busy flag
        bsy: packed enum(u1) {
            ///SPI not busy
            not_busy = 0,
            ///SPI busy
            busy = 1,
        } = .not_busy,
        ///FRE [8:8]
        ///Frame format error
        fre: packed enum(u1) {
            ///No frame format error
            no_error = 0,
            ///A frame format error occurred
            _error = 1,
        } = .no_error,
        ///FRLVL [9:10]
        ///FIFO reception level
        frlvl: packed enum(u2) {
            ///Rx FIFO Empty
            empty = 0,
            ///Rx 1/4 FIFO
            quarter = 1,
            ///Rx 1/2 FIFO
            half = 2,
            ///Rx FIFO full
            full = 3,
        } = .empty,
        ///FTLVL [11:12]
        ///FIFO transmission level
        ftlvl: packed enum(u2) {
            ///Tx FIFO Empty
            empty = 0,
            ///Tx 1/4 FIFO
            quarter = 1,
            ///Tx 1/2 FIFO
            half = 2,
            ///Tx FIFO full
            full = 3,
        } = .empty,
        _unused13: u19 = 0,
    };
    const sr_val_write = packed struct {
        ///RXNE [0:0]
        ///Receive buffer not empty
        rxne: u1 = 0,
        ///TXE [1:1]
        ///Transmit buffer empty
        txe: u1 = 1,
        _unused2: u2 = 0,
        ///CRCERR [4:4]
        ///CRC error flag
        crcerr: u1 = 0,
        ///MODF [5:5]
        ///Mode fault
        modf: u1 = 0,
        ///OVR [6:6]
        ///Overrun flag
        ovr: u1 = 0,
        ///BSY [7:7]
        ///Busy flag
        bsy: u1 = 0,
        ///FRE [8:8]
        ///Frame format error
        fre: u1 = 0,
        ///FRLVL [9:10]
        ///FIFO reception level
        frlvl: u2 = 0,
        ///FTLVL [11:12]
        ///FIFO transmission level
        ftlvl: u2 = 0,
        _unused13: u19 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40003800 + 0x8);

    //////////////////////////
    ///DR
    const dr_val = packed struct {
        ///DR [0:15]
        ///Data register
        dr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///data register
    pub const dr = Register(dr_val).init(0x40003800 + 0xC);

    //////////////////////////
    ///CRCPR
    const crcpr_val = packed struct {
        ///CRCPOLY [0:15]
        ///CRC polynomial register
        crcpoly: u16 = 7,
        _unused16: u16 = 0,
    };
    ///CRC polynomial register
    pub const crcpr = Register(crcpr_val).init(0x40003800 + 0x10);

    //////////////////////////
    ///RXCRCR
    const rxcrcr_val = packed struct {
        ///RxCRC [0:15]
        ///Rx CRC register
        rx_crc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///RX CRC register
    pub const rxcrcr = RegisterRW(rxcrcr_val, void).init(0x40003800 + 0x14);

    //////////////////////////
    ///TXCRCR
    const txcrcr_val = packed struct {
        ///TxCRC [0:15]
        ///Tx CRC register
        tx_crc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///TX CRC register
    pub const txcrcr = RegisterRW(txcrcr_val, void).init(0x40003800 + 0x18);

    //////////////////////////
    ///I2SCFGR
    const i2scfgr_val = packed struct {
        ///CHLEN [0:0]
        ///Channel length (number of bits per audio
        ///channel)
        chlen: packed enum(u1) {
            ///16-bit wide
            sixteen_bit = 0,
            ///32-bit wide
            thirty_two_bit = 1,
        } = .sixteen_bit,
        ///DATLEN [1:2]
        ///Data length to be
        ///transferred
        datlen: packed enum(u2) {
            ///16-bit data length
            sixteen_bit = 0,
            ///24-bit data length
            twenty_four_bit = 1,
            ///32-bit data length
            thirty_two_bit = 2,
        } = .sixteen_bit,
        ///CKPOL [3:3]
        ///Steady state clock
        ///polarity
        ckpol: packed enum(u1) {
            ///I2S clock inactive state is low level
            idle_low = 0,
            ///I2S clock inactive state is high level
            idle_high = 1,
        } = .idle_low,
        ///I2SSTD [4:5]
        ///I2S standard selection
        i2sstd: packed enum(u2) {
            ///I2S Philips standard
            philips = 0,
            ///MSB justified standard
            msb = 1,
            ///LSB justified standard
            lsb = 2,
            ///PCM standard
            pcm = 3,
        } = .philips,
        _unused6: u1 = 0,
        ///PCMSYNC [7:7]
        ///PCM frame synchronization
        pcmsync: packed enum(u1) {
            ///Short frame synchronisation
            short = 0,
            ///Long frame synchronisation
            long = 1,
        } = .short,
        ///I2SCFG [8:9]
        ///I2S configuration mode
        i2scfg: packed enum(u2) {
            ///Slave - transmit
            slave_tx = 0,
            ///Slave - receive
            slave_rx = 1,
            ///Master - transmit
            master_tx = 2,
            ///Master - receive
            master_rx = 3,
        } = .slave_tx,
        ///I2SE [10:10]
        ///I2S Enable
        i2se: packed enum(u1) {
            ///I2S peripheral is disabled
            disabled = 0,
            ///I2S peripheral is enabled
            enabled = 1,
        } = .disabled,
        ///I2SMOD [11:11]
        ///I2S mode selection
        i2smod: packed enum(u1) {
            ///SPI mode is selected
            spimode = 0,
            ///I2S mode is selected
            i2smode = 1,
        } = .spimode,
        _unused12: u20 = 0,
    };
    ///I2S configuration register
    pub const i2scfgr = Register(i2scfgr_val).init(0x40003800 + 0x1C);

    //////////////////////////
    ///I2SPR
    const i2spr_val = packed struct {
        ///I2SDIV [0:7]
        ///I2S Linear prescaler
        i2sdiv: u8 = 16,
        ///ODD [8:8]
        ///Odd factor for the
        ///prescaler
        odd: packed enum(u1) {
            ///Real divider value is I2SDIV * 2
            even = 0,
            ///Real divider value is (I2SDIV * 2) + 1
            odd = 1,
        } = .even,
        ///MCKOE [9:9]
        ///Master clock output enable
        mckoe: packed enum(u1) {
            ///Master clock output is disabled
            disabled = 0,
            ///Master clock output is enabled
            enabled = 1,
        } = .disabled,
        _unused10: u22 = 0,
    };
    ///I2S prescaler register
    pub const i2spr = Register(i2spr_val).init(0x40003800 + 0x20);
};

///Power control
pub const pwr = struct {

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        ///LPDS [0:0]
        ///Low-power deep sleep
        lpds: u1 = 0,
        ///PDDS [1:1]
        ///Power down deepsleep
        pdds: packed enum(u1) {
            ///Enter Stop mode when the CPU enters deepsleep
            stop_mode = 0,
            ///Enter Standby mode when the CPU enters deepsleep
            standby_mode = 1,
        } = .stop_mode,
        ///CWUF [2:2]
        ///Clear wakeup flag
        cwuf: u1 = 0,
        ///CSBF [3:3]
        ///Clear standby flag
        csbf: u1 = 0,
        _unused4: u4 = 0,
        ///DBP [8:8]
        ///Disable backup domain write
        ///protection
        dbp: u1 = 0,
        _unused9: u23 = 0,
    };
    ///power control register
    pub const cr = Register(cr_val).init(0x40007000 + 0x0);

    //////////////////////////
    ///CSR
    const csr_val = packed struct {
        ///WUF [0:0]
        ///Wakeup flag
        wuf: u1 = 0,
        ///SBF [1:1]
        ///Standby flag
        sbf: u1 = 0,
        _unused2: u6 = 0,
        ///EWUP1 [8:8]
        ///Enable WKUP pin 1
        ewup1: u1 = 0,
        ///EWUP2 [9:9]
        ///Enable WKUP pin 2
        ewup2: u1 = 0,
        _unused10: u1 = 0,
        ///EWUP4 [11:11]
        ///Enable WKUP pin 4
        ewup4: u1 = 0,
        ///EWUP5 [12:12]
        ///Enable WKUP pin 5
        ewup5: u1 = 0,
        ///EWUP6 [13:13]
        ///Enable WKUP pin 6
        ewup6: u1 = 0,
        ///EWUP7 [14:14]
        ///Enable WKUP pin 7
        ewup7: u1 = 0,
        _unused15: u17 = 0,
    };
    ///power control/status register
    pub const csr = Register(csr_val).init(0x40007000 + 0x4);
};

///Inter-integrated circuit
pub const i2c1 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///PE [0:0]
        ///Peripheral enable
        pe: packed enum(u1) {
            ///Peripheral disabled
            disabled = 0,
            ///Peripheral enabled
            enabled = 1,
        } = .disabled,
        ///TXIE [1:1]
        ///TX Interrupt enable
        txie: packed enum(u1) {
            ///Transmit (TXIS) interrupt disabled
            disabled = 0,
            ///Transmit (TXIS) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///RXIE [2:2]
        ///RX Interrupt enable
        rxie: packed enum(u1) {
            ///Receive (RXNE) interrupt disabled
            disabled = 0,
            ///Receive (RXNE) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///ADDRIE [3:3]
        ///Address match interrupt enable (slave
        ///only)
        addrie: packed enum(u1) {
            ///Address match (ADDR) interrupts disabled
            disabled = 0,
            ///Address match (ADDR) interrupts enabled
            enabled = 1,
        } = .disabled,
        ///NACKIE [4:4]
        ///Not acknowledge received interrupt
        ///enable
        nackie: packed enum(u1) {
            ///Not acknowledge (NACKF) received interrupts disabled
            disabled = 0,
            ///Not acknowledge (NACKF) received interrupts enabled
            enabled = 1,
        } = .disabled,
        ///STOPIE [5:5]
        ///STOP detection Interrupt
        ///enable
        stopie: packed enum(u1) {
            ///Stop detection (STOPF) interrupt disabled
            disabled = 0,
            ///Stop detection (STOPF) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transfer Complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Transfer Complete interrupt disabled
            disabled = 0,
            ///Transfer Complete interrupt enabled
            enabled = 1,
        } = .disabled,
        ///ERRIE [7:7]
        ///Error interrupts enable
        errie: packed enum(u1) {
            ///Error detection interrupts disabled
            disabled = 0,
            ///Error detection interrupts enabled
            enabled = 1,
        } = .disabled,
        ///DNF [8:11]
        ///Digital noise filter
        dnf: packed enum(u4) {
            ///Digital filter disabled
            no_filter = 0,
            ///Digital filter enabled and filtering capability up to 1 tI2CCLK
            filter1 = 1,
            ///Digital filter enabled and filtering capability up to 2 tI2CCLK
            filter2 = 2,
            ///Digital filter enabled and filtering capability up to 3 tI2CCLK
            filter3 = 3,
            ///Digital filter enabled and filtering capability up to 4 tI2CCLK
            filter4 = 4,
            ///Digital filter enabled and filtering capability up to 5 tI2CCLK
            filter5 = 5,
            ///Digital filter enabled and filtering capability up to 6 tI2CCLK
            filter6 = 6,
            ///Digital filter enabled and filtering capability up to 7 tI2CCLK
            filter7 = 7,
            ///Digital filter enabled and filtering capability up to 8 tI2CCLK
            filter8 = 8,
            ///Digital filter enabled and filtering capability up to 9 tI2CCLK
            filter9 = 9,
            ///Digital filter enabled and filtering capability up to 10 tI2CCLK
            filter10 = 10,
            ///Digital filter enabled and filtering capability up to 11 tI2CCLK
            filter11 = 11,
            ///Digital filter enabled and filtering capability up to 12 tI2CCLK
            filter12 = 12,
            ///Digital filter enabled and filtering capability up to 13 tI2CCLK
            filter13 = 13,
            ///Digital filter enabled and filtering capability up to 14 tI2CCLK
            filter14 = 14,
            ///Digital filter enabled and filtering capability up to 15 tI2CCLK
            filter15 = 15,
        } = .no_filter,
        ///ANFOFF [12:12]
        ///Analog noise filter OFF
        anfoff: packed enum(u1) {
            ///Analog noise filter enabled
            enabled = 0,
            ///Analog noise filter disabled
            disabled = 1,
        } = .enabled,
        ///SWRST [13:13]
        ///Software reset
        swrst: u1 = 0,
        ///TXDMAEN [14:14]
        ///DMA transmission requests
        ///enable
        txdmaen: packed enum(u1) {
            ///DMA mode disabled for transmission
            disabled = 0,
            ///DMA mode enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RXDMAEN [15:15]
        ///DMA reception requests
        ///enable
        rxdmaen: packed enum(u1) {
            ///DMA mode disabled for reception
            disabled = 0,
            ///DMA mode enabled for reception
            enabled = 1,
        } = .disabled,
        ///SBC [16:16]
        ///Slave byte control
        sbc: packed enum(u1) {
            ///Slave byte control disabled
            disabled = 0,
            ///Slave byte control enabled
            enabled = 1,
        } = .disabled,
        ///NOSTRETCH [17:17]
        ///Clock stretching disable
        nostretch: packed enum(u1) {
            ///Clock stretching enabled
            enabled = 0,
            ///Clock stretching disabled
            disabled = 1,
        } = .enabled,
        ///WUPEN [18:18]
        ///Wakeup from STOP enable
        wupen: packed enum(u1) {
            ///Wakeup from Stop mode disabled
            disabled = 0,
            ///Wakeup from Stop mode enabled
            enabled = 1,
        } = .disabled,
        ///GCEN [19:19]
        ///General call enable
        gcen: packed enum(u1) {
            ///General call disabled. Address 0b00000000 is NACKed
            disabled = 0,
            ///General call enabled. Address 0b00000000 is ACKed
            enabled = 1,
        } = .disabled,
        ///SMBHEN [20:20]
        ///SMBus Host address enable
        smbhen: packed enum(u1) {
            ///Host address disabled. Address 0b0001000x is NACKed
            disabled = 0,
            ///Host address enabled. Address 0b0001000x is ACKed
            enabled = 1,
        } = .disabled,
        ///SMBDEN [21:21]
        ///SMBus Device Default address
        ///enable
        smbden: packed enum(u1) {
            ///Device default address disabled. Address 0b1100001x is NACKed
            disabled = 0,
            ///Device default address enabled. Address 0b1100001x is ACKed
            enabled = 1,
        } = .disabled,
        ///ALERTEN [22:22]
        ///SMBUS alert enable
        alerten: packed enum(u1) {
            ///In device mode (SMBHEN=Disabled) Releases SMBA pin high and Alert Response Address Header disabled (0001100x) followed by NACK. In host mode (SMBHEN=Enabled) SMBus Alert pin (SMBA) not supported
            disabled = 0,
            ///In device mode (SMBHEN=Disabled) Drives SMBA pin low and Alert Response Address Header enabled (0001100x) followed by ACK.In host mode (SMBHEN=Enabled) SMBus Alert pin (SMBA) supported
            enabled = 1,
        } = .disabled,
        ///PECEN [23:23]
        ///PEC enable
        pecen: packed enum(u1) {
            ///PEC calculation disabled
            disabled = 0,
            ///PEC calculation enabled
            enabled = 1,
        } = .disabled,
        _unused24: u8 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40005400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///SADD [0:9]
        ///Slave address bit 9:8 (master
        ///mode)
        sadd: u10 = 0,
        ///RD_WRN [10:10]
        ///Transfer direction (master
        ///mode)
        rd_wrn: packed enum(u1) {
            ///Master requests a write transfer
            write = 0,
            ///Master requests a read transfer
            read = 1,
        } = .write,
        ///ADD10 [11:11]
        ///10-bit addressing mode (master
        ///mode)
        add10: packed enum(u1) {
            ///The master operates in 7-bit addressing mode
            bit7 = 0,
            ///The master operates in 10-bit addressing mode
            bit10 = 1,
        } = .bit7,
        ///HEAD10R [12:12]
        ///10-bit address header only read
        ///direction (master receiver mode)
        head10r: packed enum(u1) {
            ///The master sends the complete 10 bit slave address read sequence
            complete = 0,
            ///The master only sends the 1st 7 bits of the 10 bit address, followed by Read direction
            partial = 1,
        } = .complete,
        ///START [13:13]
        ///Start generation
        start: packed enum(u1) {
            ///No Start generation
            no_start = 0,
            ///Restart/Start generation
            start = 1,
        } = .no_start,
        ///STOP [14:14]
        ///Stop generation (master
        ///mode)
        stop: packed enum(u1) {
            ///No Stop generation
            no_stop = 0,
            ///Stop generation after current byte transfer
            stop = 1,
        } = .no_stop,
        ///NACK [15:15]
        ///NACK generation (slave
        ///mode)
        nack: packed enum(u1) {
            ///an ACK is sent after current received byte
            ack = 0,
            ///a NACK is sent after current received byte
            nack = 1,
        } = .ack,
        ///NBYTES [16:23]
        ///Number of bytes
        nbytes: u8 = 0,
        ///RELOAD [24:24]
        ///NBYTES reload mode
        reload: packed enum(u1) {
            ///The transfer is completed after the NBYTES data transfer (STOP or RESTART will follow)
            completed = 0,
            ///The transfer is not completed after the NBYTES data transfer (NBYTES will be reloaded)
            not_completed = 1,
        } = .completed,
        ///AUTOEND [25:25]
        ///Automatic end mode (master
        ///mode)
        autoend: packed enum(u1) {
            ///Software end mode: TC flag is set when NBYTES data are transferred, stretching SCL low
            software = 0,
            ///Automatic end mode: a STOP condition is automatically sent when NBYTES data are transferred
            automatic = 1,
        } = .software,
        ///PECBYTE [26:26]
        ///Packet error checking byte
        pecbyte: packed enum(u1) {
            ///No PEC transfer
            no_pec = 0,
            ///PEC transmission/reception is requested
            pec = 1,
        } = .no_pec,
        _unused27: u5 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40005400 + 0x4);

    //////////////////////////
    ///OAR1
    const oar1_val = packed struct {
        ///OA1 [0:9]
        ///Interface address
        oa1: u10 = 0,
        ///OA1MODE [10:10]
        ///Own Address 1 10-bit mode
        oa1mode: packed enum(u1) {
            ///Own address 1 is a 7-bit address
            bit7 = 0,
            ///Own address 1 is a 10-bit address
            bit10 = 1,
        } = .bit7,
        _unused11: u4 = 0,
        ///OA1EN [15:15]
        ///Own Address 1 enable
        oa1en: packed enum(u1) {
            ///Own address 1 disabled. The received slave address OA1 is NACKed
            disabled = 0,
            ///Own address 1 enabled. The received slave address OA1 is ACKed
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///Own address register 1
    pub const oar1 = Register(oar1_val).init(0x40005400 + 0x8);

    //////////////////////////
    ///OAR2
    const oar2_val = packed struct {
        _unused0: u1 = 0,
        ///OA2 [1:7]
        ///Interface address
        oa2: u7 = 0,
        ///OA2MSK [8:10]
        ///Own Address 2 masks
        oa2msk: packed enum(u3) {
            ///No mask
            no_mask = 0,
            ///OA2[1] is masked and don’t care. Only OA2[7:2] are compared
            mask1 = 1,
            ///OA2[2:1] are masked and don’t care. Only OA2[7:3] are compared
            mask2 = 2,
            ///OA2[3:1] are masked and don’t care. Only OA2[7:4] are compared
            mask3 = 3,
            ///OA2[4:1] are masked and don’t care. Only OA2[7:5] are compared
            mask4 = 4,
            ///OA2[5:1] are masked and don’t care. Only OA2[7:6] are compared
            mask5 = 5,
            ///OA2[6:1] are masked and don’t care. Only OA2[7] is compared.
            mask6 = 6,
            ///OA2[7:1] are masked and don’t care. No comparison is done, and all (except reserved) 7-bit received addresses are acknowledged
            mask7 = 7,
        } = .no_mask,
        _unused11: u4 = 0,
        ///OA2EN [15:15]
        ///Own Address 2 enable
        oa2en: packed enum(u1) {
            ///Own address 2 disabled. The received slave address OA2 is NACKed
            disabled = 0,
            ///Own address 2 enabled. The received slave address OA2 is ACKed
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///Own address register 2
    pub const oar2 = Register(oar2_val).init(0x40005400 + 0xC);

    //////////////////////////
    ///TIMINGR
    const timingr_val = packed struct {
        ///SCLL [0:7]
        ///SCL low period (master
        ///mode)
        scll: u8 = 0,
        ///SCLH [8:15]
        ///SCL high period (master
        ///mode)
        sclh: u8 = 0,
        ///SDADEL [16:19]
        ///Data hold time
        sdadel: u4 = 0,
        ///SCLDEL [20:23]
        ///Data setup time
        scldel: u4 = 0,
        _unused24: u4 = 0,
        ///PRESC [28:31]
        ///Timing prescaler
        presc: u4 = 0,
    };
    ///Timing register
    pub const timingr = Register(timingr_val).init(0x40005400 + 0x10);

    //////////////////////////
    ///TIMEOUTR
    const timeoutr_val = packed struct {
        ///TIMEOUTA [0:11]
        ///Bus timeout A
        timeouta: u12 = 0,
        ///TIDLE [12:12]
        ///Idle clock timeout
        ///detection
        tidle: packed enum(u1) {
            ///TIMEOUTA is used to detect SCL low timeout
            disabled = 0,
            ///TIMEOUTA is used to detect both SCL and SDA high timeout (bus idle condition)
            enabled = 1,
        } = .disabled,
        _unused13: u2 = 0,
        ///TIMOUTEN [15:15]
        ///Clock timeout enable
        timouten: packed enum(u1) {
            ///SCL timeout detection is disabled
            disabled = 0,
            ///SCL timeout detection is enabled
            enabled = 1,
        } = .disabled,
        ///TIMEOUTB [16:27]
        ///Bus timeout B
        timeoutb: u12 = 0,
        _unused28: u3 = 0,
        ///TEXTEN [31:31]
        ///Extended clock timeout
        ///enable
        texten: packed enum(u1) {
            ///Extended clock timeout detection is disabled
            disabled = 0,
            ///Extended clock timeout detection is enabled
            enabled = 1,
        } = .disabled,
    };
    ///Status register 1
    pub const timeoutr = Register(timeoutr_val).init(0x40005400 + 0x14);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///TXE [0:0]
        ///Transmit data register empty
        ///(transmitters)
        txe: packed enum(u1) {
            ///TXDR register not empty
            not_empty = 0,
            ///TXDR register empty
            empty = 1,
        } = .empty,
        ///TXIS [1:1]
        ///Transmit interrupt status
        ///(transmitters)
        txis: packed enum(u1) {
            ///The TXDR register is not empty
            not_empty = 0,
            ///The TXDR register is empty and the data to be transmitted must be written in the TXDR register
            empty = 1,
        } = .not_empty,
        ///RXNE [2:2]
        ///Receive data register not empty
        ///(receivers)
        rxne: packed enum(u1) {
            ///The RXDR register is empty
            empty = 0,
            ///Received data is copied into the RXDR register, and is ready to be read
            not_empty = 1,
        } = .empty,
        ///ADDR [3:3]
        ///Address matched (slave
        ///mode)
        addr: packed enum(u1) {
            ///Adress mismatched or not received
            not_match = 0,
            ///Received slave address matched with one of the enabled slave addresses
            match = 1,
        } = .not_match,
        ///NACKF [4:4]
        ///Not acknowledge received
        ///flag
        nackf: packed enum(u1) {
            ///No NACK has been received
            no_nack = 0,
            ///NACK has been received
            nack = 1,
        } = .no_nack,
        ///STOPF [5:5]
        ///Stop detection flag
        stopf: packed enum(u1) {
            ///No Stop condition detected
            no_stop = 0,
            ///Stop condition detected
            stop = 1,
        } = .no_stop,
        ///TC [6:6]
        ///Transfer Complete (master
        ///mode)
        tc: packed enum(u1) {
            ///Transfer is not complete
            not_complete = 0,
            ///NBYTES has been transfered
            complete = 1,
        } = .not_complete,
        ///TCR [7:7]
        ///Transfer Complete Reload
        tcr: packed enum(u1) {
            ///Transfer is not complete
            not_complete = 0,
            ///NBYTES has been transfered
            complete = 1,
        } = .not_complete,
        ///BERR [8:8]
        ///Bus error
        berr: packed enum(u1) {
            ///No bus error
            no_error = 0,
            ///Misplaced Start and Stop condition is detected
            _error = 1,
        } = .no_error,
        ///ARLO [9:9]
        ///Arbitration lost
        arlo: packed enum(u1) {
            ///No arbitration lost
            not_lost = 0,
            ///Arbitration lost
            lost = 1,
        } = .not_lost,
        ///OVR [10:10]
        ///Overrun/Underrun (slave
        ///mode)
        ovr: packed enum(u1) {
            ///No overrun/underrun error occurs
            no_overrun = 0,
            ///slave mode with NOSTRETCH=1, when an overrun/underrun error occurs
            overrun = 1,
        } = .no_overrun,
        ///PECERR [11:11]
        ///PEC Error in reception
        pecerr: packed enum(u1) {
            ///Received PEC does match with PEC register
            match = 0,
            ///Received PEC does not match with PEC register
            no_match = 1,
        } = .match,
        ///TIMEOUT [12:12]
        ///Timeout or t_low detection
        ///flag
        timeout: packed enum(u1) {
            ///No timeout occured
            no_timeout = 0,
            ///Timeout occured
            timeout = 1,
        } = .no_timeout,
        ///ALERT [13:13]
        ///SMBus alert
        alert: packed enum(u1) {
            ///SMBA alert is not detected
            no_alert = 0,
            ///SMBA alert event is detected on SMBA pin
            alert = 1,
        } = .no_alert,
        _unused14: u1 = 0,
        ///BUSY [15:15]
        ///Bus busy
        busy: packed enum(u1) {
            ///No communication is in progress on the bus
            not_busy = 0,
            ///A communication is in progress on the bus
            busy = 1,
        } = .not_busy,
        ///DIR [16:16]
        ///Transfer direction (Slave
        ///mode)
        dir: packed enum(u1) {
            ///Write transfer, slave enters receiver mode
            write = 0,
            ///Read transfer, slave enters transmitter mode
            read = 1,
        } = .write,
        ///ADDCODE [17:23]
        ///Address match code (Slave
        ///mode)
        addcode: u7 = 0,
        _unused24: u8 = 0,
    };
    ///Interrupt and Status register
    pub const isr = Register(isr_val).init(0x40005400 + 0x18);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        _unused0: u3 = 0,
        ///ADDRCF [3:3]
        ///Address Matched flag clear
        addrcf: packed enum(u1) {
            ///Clears the ADDR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NACKCF [4:4]
        ///Not Acknowledge flag clear
        nackcf: packed enum(u1) {
            ///Clears the NACK flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///STOPCF [5:5]
        ///Stop detection flag clear
        stopcf: packed enum(u1) {
            ///Clears the STOP flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused6: u2 = 0,
        ///BERRCF [8:8]
        ///Bus error flag clear
        berrcf: packed enum(u1) {
            ///Clears the BERR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ARLOCF [9:9]
        ///Arbitration lost flag
        ///clear
        arlocf: packed enum(u1) {
            ///Clears the ARLO flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///OVRCF [10:10]
        ///Overrun/Underrun flag
        ///clear
        ovrcf: packed enum(u1) {
            ///Clears the OVR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///PECCF [11:11]
        ///PEC Error flag clear
        peccf: packed enum(u1) {
            ///Clears the PEC flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///TIMOUTCF [12:12]
        ///Timeout detection flag
        ///clear
        timoutcf: packed enum(u1) {
            ///Clears the TIMOUT flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ALERTCF [13:13]
        ///Alert flag clear
        alertcf: packed enum(u1) {
            ///Clears the ALERT flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused14: u18 = 0,
    };
    ///Interrupt clear register
    pub const icr = RegisterRW(void, icr_val).init(0x40005400 + 0x1C);

    //////////////////////////
    ///PECR
    const pecr_val = packed struct {
        ///PEC [0:7]
        ///Packet error checking
        ///register
        pec: u8 = 0,
        _unused8: u24 = 0,
    };
    ///PEC register
    pub const pecr = RegisterRW(pecr_val, void).init(0x40005400 + 0x20);

    //////////////////////////
    ///RXDR
    const rxdr_val = packed struct {
        ///RXDATA [0:7]
        ///8-bit receive data
        rxdata: u8 = 0,
        _unused8: u24 = 0,
    };
    ///Receive data register
    pub const rxdr = RegisterRW(rxdr_val, void).init(0x40005400 + 0x24);

    //////////////////////////
    ///TXDR
    const txdr_val = packed struct {
        ///TXDATA [0:7]
        ///8-bit transmit data
        txdata: u8 = 0,
        _unused8: u24 = 0,
    };
    ///Transmit data register
    pub const txdr = Register(txdr_val).init(0x40005400 + 0x28);
};

///Inter-integrated circuit
pub const i2c2 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///PE [0:0]
        ///Peripheral enable
        pe: packed enum(u1) {
            ///Peripheral disabled
            disabled = 0,
            ///Peripheral enabled
            enabled = 1,
        } = .disabled,
        ///TXIE [1:1]
        ///TX Interrupt enable
        txie: packed enum(u1) {
            ///Transmit (TXIS) interrupt disabled
            disabled = 0,
            ///Transmit (TXIS) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///RXIE [2:2]
        ///RX Interrupt enable
        rxie: packed enum(u1) {
            ///Receive (RXNE) interrupt disabled
            disabled = 0,
            ///Receive (RXNE) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///ADDRIE [3:3]
        ///Address match interrupt enable (slave
        ///only)
        addrie: packed enum(u1) {
            ///Address match (ADDR) interrupts disabled
            disabled = 0,
            ///Address match (ADDR) interrupts enabled
            enabled = 1,
        } = .disabled,
        ///NACKIE [4:4]
        ///Not acknowledge received interrupt
        ///enable
        nackie: packed enum(u1) {
            ///Not acknowledge (NACKF) received interrupts disabled
            disabled = 0,
            ///Not acknowledge (NACKF) received interrupts enabled
            enabled = 1,
        } = .disabled,
        ///STOPIE [5:5]
        ///STOP detection Interrupt
        ///enable
        stopie: packed enum(u1) {
            ///Stop detection (STOPF) interrupt disabled
            disabled = 0,
            ///Stop detection (STOPF) interrupt enabled
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transfer Complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Transfer Complete interrupt disabled
            disabled = 0,
            ///Transfer Complete interrupt enabled
            enabled = 1,
        } = .disabled,
        ///ERRIE [7:7]
        ///Error interrupts enable
        errie: packed enum(u1) {
            ///Error detection interrupts disabled
            disabled = 0,
            ///Error detection interrupts enabled
            enabled = 1,
        } = .disabled,
        ///DNF [8:11]
        ///Digital noise filter
        dnf: packed enum(u4) {
            ///Digital filter disabled
            no_filter = 0,
            ///Digital filter enabled and filtering capability up to 1 tI2CCLK
            filter1 = 1,
            ///Digital filter enabled and filtering capability up to 2 tI2CCLK
            filter2 = 2,
            ///Digital filter enabled and filtering capability up to 3 tI2CCLK
            filter3 = 3,
            ///Digital filter enabled and filtering capability up to 4 tI2CCLK
            filter4 = 4,
            ///Digital filter enabled and filtering capability up to 5 tI2CCLK
            filter5 = 5,
            ///Digital filter enabled and filtering capability up to 6 tI2CCLK
            filter6 = 6,
            ///Digital filter enabled and filtering capability up to 7 tI2CCLK
            filter7 = 7,
            ///Digital filter enabled and filtering capability up to 8 tI2CCLK
            filter8 = 8,
            ///Digital filter enabled and filtering capability up to 9 tI2CCLK
            filter9 = 9,
            ///Digital filter enabled and filtering capability up to 10 tI2CCLK
            filter10 = 10,
            ///Digital filter enabled and filtering capability up to 11 tI2CCLK
            filter11 = 11,
            ///Digital filter enabled and filtering capability up to 12 tI2CCLK
            filter12 = 12,
            ///Digital filter enabled and filtering capability up to 13 tI2CCLK
            filter13 = 13,
            ///Digital filter enabled and filtering capability up to 14 tI2CCLK
            filter14 = 14,
            ///Digital filter enabled and filtering capability up to 15 tI2CCLK
            filter15 = 15,
        } = .no_filter,
        ///ANFOFF [12:12]
        ///Analog noise filter OFF
        anfoff: packed enum(u1) {
            ///Analog noise filter enabled
            enabled = 0,
            ///Analog noise filter disabled
            disabled = 1,
        } = .enabled,
        ///SWRST [13:13]
        ///Software reset
        swrst: u1 = 0,
        ///TXDMAEN [14:14]
        ///DMA transmission requests
        ///enable
        txdmaen: packed enum(u1) {
            ///DMA mode disabled for transmission
            disabled = 0,
            ///DMA mode enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RXDMAEN [15:15]
        ///DMA reception requests
        ///enable
        rxdmaen: packed enum(u1) {
            ///DMA mode disabled for reception
            disabled = 0,
            ///DMA mode enabled for reception
            enabled = 1,
        } = .disabled,
        ///SBC [16:16]
        ///Slave byte control
        sbc: packed enum(u1) {
            ///Slave byte control disabled
            disabled = 0,
            ///Slave byte control enabled
            enabled = 1,
        } = .disabled,
        ///NOSTRETCH [17:17]
        ///Clock stretching disable
        nostretch: packed enum(u1) {
            ///Clock stretching enabled
            enabled = 0,
            ///Clock stretching disabled
            disabled = 1,
        } = .enabled,
        ///WUPEN [18:18]
        ///Wakeup from STOP enable
        wupen: packed enum(u1) {
            ///Wakeup from Stop mode disabled
            disabled = 0,
            ///Wakeup from Stop mode enabled
            enabled = 1,
        } = .disabled,
        ///GCEN [19:19]
        ///General call enable
        gcen: packed enum(u1) {
            ///General call disabled. Address 0b00000000 is NACKed
            disabled = 0,
            ///General call enabled. Address 0b00000000 is ACKed
            enabled = 1,
        } = .disabled,
        ///SMBHEN [20:20]
        ///SMBus Host address enable
        smbhen: packed enum(u1) {
            ///Host address disabled. Address 0b0001000x is NACKed
            disabled = 0,
            ///Host address enabled. Address 0b0001000x is ACKed
            enabled = 1,
        } = .disabled,
        ///SMBDEN [21:21]
        ///SMBus Device Default address
        ///enable
        smbden: packed enum(u1) {
            ///Device default address disabled. Address 0b1100001x is NACKed
            disabled = 0,
            ///Device default address enabled. Address 0b1100001x is ACKed
            enabled = 1,
        } = .disabled,
        ///ALERTEN [22:22]
        ///SMBUS alert enable
        alerten: packed enum(u1) {
            ///In device mode (SMBHEN=Disabled) Releases SMBA pin high and Alert Response Address Header disabled (0001100x) followed by NACK. In host mode (SMBHEN=Enabled) SMBus Alert pin (SMBA) not supported
            disabled = 0,
            ///In device mode (SMBHEN=Disabled) Drives SMBA pin low and Alert Response Address Header enabled (0001100x) followed by ACK.In host mode (SMBHEN=Enabled) SMBus Alert pin (SMBA) supported
            enabled = 1,
        } = .disabled,
        ///PECEN [23:23]
        ///PEC enable
        pecen: packed enum(u1) {
            ///PEC calculation disabled
            disabled = 0,
            ///PEC calculation enabled
            enabled = 1,
        } = .disabled,
        _unused24: u8 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40005800 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///SADD [0:9]
        ///Slave address bit 9:8 (master
        ///mode)
        sadd: u10 = 0,
        ///RD_WRN [10:10]
        ///Transfer direction (master
        ///mode)
        rd_wrn: packed enum(u1) {
            ///Master requests a write transfer
            write = 0,
            ///Master requests a read transfer
            read = 1,
        } = .write,
        ///ADD10 [11:11]
        ///10-bit addressing mode (master
        ///mode)
        add10: packed enum(u1) {
            ///The master operates in 7-bit addressing mode
            bit7 = 0,
            ///The master operates in 10-bit addressing mode
            bit10 = 1,
        } = .bit7,
        ///HEAD10R [12:12]
        ///10-bit address header only read
        ///direction (master receiver mode)
        head10r: packed enum(u1) {
            ///The master sends the complete 10 bit slave address read sequence
            complete = 0,
            ///The master only sends the 1st 7 bits of the 10 bit address, followed by Read direction
            partial = 1,
        } = .complete,
        ///START [13:13]
        ///Start generation
        start: packed enum(u1) {
            ///No Start generation
            no_start = 0,
            ///Restart/Start generation
            start = 1,
        } = .no_start,
        ///STOP [14:14]
        ///Stop generation (master
        ///mode)
        stop: packed enum(u1) {
            ///No Stop generation
            no_stop = 0,
            ///Stop generation after current byte transfer
            stop = 1,
        } = .no_stop,
        ///NACK [15:15]
        ///NACK generation (slave
        ///mode)
        nack: packed enum(u1) {
            ///an ACK is sent after current received byte
            ack = 0,
            ///a NACK is sent after current received byte
            nack = 1,
        } = .ack,
        ///NBYTES [16:23]
        ///Number of bytes
        nbytes: u8 = 0,
        ///RELOAD [24:24]
        ///NBYTES reload mode
        reload: packed enum(u1) {
            ///The transfer is completed after the NBYTES data transfer (STOP or RESTART will follow)
            completed = 0,
            ///The transfer is not completed after the NBYTES data transfer (NBYTES will be reloaded)
            not_completed = 1,
        } = .completed,
        ///AUTOEND [25:25]
        ///Automatic end mode (master
        ///mode)
        autoend: packed enum(u1) {
            ///Software end mode: TC flag is set when NBYTES data are transferred, stretching SCL low
            software = 0,
            ///Automatic end mode: a STOP condition is automatically sent when NBYTES data are transferred
            automatic = 1,
        } = .software,
        ///PECBYTE [26:26]
        ///Packet error checking byte
        pecbyte: packed enum(u1) {
            ///No PEC transfer
            no_pec = 0,
            ///PEC transmission/reception is requested
            pec = 1,
        } = .no_pec,
        _unused27: u5 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40005800 + 0x4);

    //////////////////////////
    ///OAR1
    const oar1_val = packed struct {
        ///OA1 [0:9]
        ///Interface address
        oa1: u10 = 0,
        ///OA1MODE [10:10]
        ///Own Address 1 10-bit mode
        oa1mode: packed enum(u1) {
            ///Own address 1 is a 7-bit address
            bit7 = 0,
            ///Own address 1 is a 10-bit address
            bit10 = 1,
        } = .bit7,
        _unused11: u4 = 0,
        ///OA1EN [15:15]
        ///Own Address 1 enable
        oa1en: packed enum(u1) {
            ///Own address 1 disabled. The received slave address OA1 is NACKed
            disabled = 0,
            ///Own address 1 enabled. The received slave address OA1 is ACKed
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///Own address register 1
    pub const oar1 = Register(oar1_val).init(0x40005800 + 0x8);

    //////////////////////////
    ///OAR2
    const oar2_val = packed struct {
        _unused0: u1 = 0,
        ///OA2 [1:7]
        ///Interface address
        oa2: u7 = 0,
        ///OA2MSK [8:10]
        ///Own Address 2 masks
        oa2msk: packed enum(u3) {
            ///No mask
            no_mask = 0,
            ///OA2[1] is masked and don’t care. Only OA2[7:2] are compared
            mask1 = 1,
            ///OA2[2:1] are masked and don’t care. Only OA2[7:3] are compared
            mask2 = 2,
            ///OA2[3:1] are masked and don’t care. Only OA2[7:4] are compared
            mask3 = 3,
            ///OA2[4:1] are masked and don’t care. Only OA2[7:5] are compared
            mask4 = 4,
            ///OA2[5:1] are masked and don’t care. Only OA2[7:6] are compared
            mask5 = 5,
            ///OA2[6:1] are masked and don’t care. Only OA2[7] is compared.
            mask6 = 6,
            ///OA2[7:1] are masked and don’t care. No comparison is done, and all (except reserved) 7-bit received addresses are acknowledged
            mask7 = 7,
        } = .no_mask,
        _unused11: u4 = 0,
        ///OA2EN [15:15]
        ///Own Address 2 enable
        oa2en: packed enum(u1) {
            ///Own address 2 disabled. The received slave address OA2 is NACKed
            disabled = 0,
            ///Own address 2 enabled. The received slave address OA2 is ACKed
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///Own address register 2
    pub const oar2 = Register(oar2_val).init(0x40005800 + 0xC);

    //////////////////////////
    ///TIMINGR
    const timingr_val = packed struct {
        ///SCLL [0:7]
        ///SCL low period (master
        ///mode)
        scll: u8 = 0,
        ///SCLH [8:15]
        ///SCL high period (master
        ///mode)
        sclh: u8 = 0,
        ///SDADEL [16:19]
        ///Data hold time
        sdadel: u4 = 0,
        ///SCLDEL [20:23]
        ///Data setup time
        scldel: u4 = 0,
        _unused24: u4 = 0,
        ///PRESC [28:31]
        ///Timing prescaler
        presc: u4 = 0,
    };
    ///Timing register
    pub const timingr = Register(timingr_val).init(0x40005800 + 0x10);

    //////////////////////////
    ///TIMEOUTR
    const timeoutr_val = packed struct {
        ///TIMEOUTA [0:11]
        ///Bus timeout A
        timeouta: u12 = 0,
        ///TIDLE [12:12]
        ///Idle clock timeout
        ///detection
        tidle: packed enum(u1) {
            ///TIMEOUTA is used to detect SCL low timeout
            disabled = 0,
            ///TIMEOUTA is used to detect both SCL and SDA high timeout (bus idle condition)
            enabled = 1,
        } = .disabled,
        _unused13: u2 = 0,
        ///TIMOUTEN [15:15]
        ///Clock timeout enable
        timouten: packed enum(u1) {
            ///SCL timeout detection is disabled
            disabled = 0,
            ///SCL timeout detection is enabled
            enabled = 1,
        } = .disabled,
        ///TIMEOUTB [16:27]
        ///Bus timeout B
        timeoutb: u12 = 0,
        _unused28: u3 = 0,
        ///TEXTEN [31:31]
        ///Extended clock timeout
        ///enable
        texten: packed enum(u1) {
            ///Extended clock timeout detection is disabled
            disabled = 0,
            ///Extended clock timeout detection is enabled
            enabled = 1,
        } = .disabled,
    };
    ///Status register 1
    pub const timeoutr = Register(timeoutr_val).init(0x40005800 + 0x14);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///TXE [0:0]
        ///Transmit data register empty
        ///(transmitters)
        txe: packed enum(u1) {
            ///TXDR register not empty
            not_empty = 0,
            ///TXDR register empty
            empty = 1,
        } = .empty,
        ///TXIS [1:1]
        ///Transmit interrupt status
        ///(transmitters)
        txis: packed enum(u1) {
            ///The TXDR register is not empty
            not_empty = 0,
            ///The TXDR register is empty and the data to be transmitted must be written in the TXDR register
            empty = 1,
        } = .not_empty,
        ///RXNE [2:2]
        ///Receive data register not empty
        ///(receivers)
        rxne: packed enum(u1) {
            ///The RXDR register is empty
            empty = 0,
            ///Received data is copied into the RXDR register, and is ready to be read
            not_empty = 1,
        } = .empty,
        ///ADDR [3:3]
        ///Address matched (slave
        ///mode)
        addr: packed enum(u1) {
            ///Adress mismatched or not received
            not_match = 0,
            ///Received slave address matched with one of the enabled slave addresses
            match = 1,
        } = .not_match,
        ///NACKF [4:4]
        ///Not acknowledge received
        ///flag
        nackf: packed enum(u1) {
            ///No NACK has been received
            no_nack = 0,
            ///NACK has been received
            nack = 1,
        } = .no_nack,
        ///STOPF [5:5]
        ///Stop detection flag
        stopf: packed enum(u1) {
            ///No Stop condition detected
            no_stop = 0,
            ///Stop condition detected
            stop = 1,
        } = .no_stop,
        ///TC [6:6]
        ///Transfer Complete (master
        ///mode)
        tc: packed enum(u1) {
            ///Transfer is not complete
            not_complete = 0,
            ///NBYTES has been transfered
            complete = 1,
        } = .not_complete,
        ///TCR [7:7]
        ///Transfer Complete Reload
        tcr: packed enum(u1) {
            ///Transfer is not complete
            not_complete = 0,
            ///NBYTES has been transfered
            complete = 1,
        } = .not_complete,
        ///BERR [8:8]
        ///Bus error
        berr: packed enum(u1) {
            ///No bus error
            no_error = 0,
            ///Misplaced Start and Stop condition is detected
            _error = 1,
        } = .no_error,
        ///ARLO [9:9]
        ///Arbitration lost
        arlo: packed enum(u1) {
            ///No arbitration lost
            not_lost = 0,
            ///Arbitration lost
            lost = 1,
        } = .not_lost,
        ///OVR [10:10]
        ///Overrun/Underrun (slave
        ///mode)
        ovr: packed enum(u1) {
            ///No overrun/underrun error occurs
            no_overrun = 0,
            ///slave mode with NOSTRETCH=1, when an overrun/underrun error occurs
            overrun = 1,
        } = .no_overrun,
        ///PECERR [11:11]
        ///PEC Error in reception
        pecerr: packed enum(u1) {
            ///Received PEC does match with PEC register
            match = 0,
            ///Received PEC does not match with PEC register
            no_match = 1,
        } = .match,
        ///TIMEOUT [12:12]
        ///Timeout or t_low detection
        ///flag
        timeout: packed enum(u1) {
            ///No timeout occured
            no_timeout = 0,
            ///Timeout occured
            timeout = 1,
        } = .no_timeout,
        ///ALERT [13:13]
        ///SMBus alert
        alert: packed enum(u1) {
            ///SMBA alert is not detected
            no_alert = 0,
            ///SMBA alert event is detected on SMBA pin
            alert = 1,
        } = .no_alert,
        _unused14: u1 = 0,
        ///BUSY [15:15]
        ///Bus busy
        busy: packed enum(u1) {
            ///No communication is in progress on the bus
            not_busy = 0,
            ///A communication is in progress on the bus
            busy = 1,
        } = .not_busy,
        ///DIR [16:16]
        ///Transfer direction (Slave
        ///mode)
        dir: packed enum(u1) {
            ///Write transfer, slave enters receiver mode
            write = 0,
            ///Read transfer, slave enters transmitter mode
            read = 1,
        } = .write,
        ///ADDCODE [17:23]
        ///Address match code (Slave
        ///mode)
        addcode: u7 = 0,
        _unused24: u8 = 0,
    };
    ///Interrupt and Status register
    pub const isr = Register(isr_val).init(0x40005800 + 0x18);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        _unused0: u3 = 0,
        ///ADDRCF [3:3]
        ///Address Matched flag clear
        addrcf: packed enum(u1) {
            ///Clears the ADDR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NACKCF [4:4]
        ///Not Acknowledge flag clear
        nackcf: packed enum(u1) {
            ///Clears the NACK flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///STOPCF [5:5]
        ///Stop detection flag clear
        stopcf: packed enum(u1) {
            ///Clears the STOP flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused6: u2 = 0,
        ///BERRCF [8:8]
        ///Bus error flag clear
        berrcf: packed enum(u1) {
            ///Clears the BERR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ARLOCF [9:9]
        ///Arbitration lost flag
        ///clear
        arlocf: packed enum(u1) {
            ///Clears the ARLO flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///OVRCF [10:10]
        ///Overrun/Underrun flag
        ///clear
        ovrcf: packed enum(u1) {
            ///Clears the OVR flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///PECCF [11:11]
        ///PEC Error flag clear
        peccf: packed enum(u1) {
            ///Clears the PEC flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///TIMOUTCF [12:12]
        ///Timeout detection flag
        ///clear
        timoutcf: packed enum(u1) {
            ///Clears the TIMOUT flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ALERTCF [13:13]
        ///Alert flag clear
        alertcf: packed enum(u1) {
            ///Clears the ALERT flag in ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused14: u18 = 0,
    };
    ///Interrupt clear register
    pub const icr = RegisterRW(void, icr_val).init(0x40005800 + 0x1C);

    //////////////////////////
    ///PECR
    const pecr_val = packed struct {
        ///PEC [0:7]
        ///Packet error checking
        ///register
        pec: u8 = 0,
        _unused8: u24 = 0,
    };
    ///PEC register
    pub const pecr = RegisterRW(pecr_val, void).init(0x40005800 + 0x20);

    //////////////////////////
    ///RXDR
    const rxdr_val = packed struct {
        ///RXDATA [0:7]
        ///8-bit receive data
        rxdata: u8 = 0,
        _unused8: u24 = 0,
    };
    ///Receive data register
    pub const rxdr = RegisterRW(rxdr_val, void).init(0x40005800 + 0x24);

    //////////////////////////
    ///TXDR
    const txdr_val = packed struct {
        ///TXDATA [0:7]
        ///8-bit transmit data
        txdata: u8 = 0,
        _unused8: u24 = 0,
    };
    ///Transmit data register
    pub const txdr = Register(txdr_val).init(0x40005800 + 0x28);
};

///Independent watchdog
pub const iwdg = struct {

    //////////////////////////
    ///KR
    const kr_val = packed struct {
        ///KEY [0:15]
        ///Key value
        key: packed enum(u16) {
            ///Enable access to PR, RLR and WINR registers (0x5555)
            enable = 21845,
            ///Reset the watchdog value (0xAAAA)
            reset = 43690,
            ///Start the watchdog (0xCCCC)
            start = 52428,
            _zero = 0,
        } = ._zero,
        _unused16: u16 = 0,
    };
    ///Key register
    pub const kr = RegisterRW(void, kr_val).init(0x40003000 + 0x0);

    //////////////////////////
    ///PR
    const pr_val = packed struct {
        ///PR [0:2]
        ///Prescaler divider
        pr: packed enum(u3) {
            ///Divider /4
            divide_by4 = 0,
            ///Divider /8
            divide_by8 = 1,
            ///Divider /16
            divide_by16 = 2,
            ///Divider /32
            divide_by32 = 3,
            ///Divider /64
            divide_by64 = 4,
            ///Divider /128
            divide_by128 = 5,
            ///Divider /256
            divide_by256 = 6,
            ///Divider /256
            divide_by256bis = 7,
        } = .divide_by4,
        _unused3: u29 = 0,
    };
    ///Prescaler register
    pub const pr = Register(pr_val).init(0x40003000 + 0x4);

    //////////////////////////
    ///RLR
    const rlr_val = packed struct {
        ///RL [0:11]
        ///Watchdog counter reload
        ///value
        rl: u12 = 4095,
        _unused12: u20 = 0,
    };
    ///Reload register
    pub const rlr = Register(rlr_val).init(0x40003000 + 0x8);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///PVU [0:0]
        ///Watchdog prescaler value
        ///update
        pvu: u1 = 0,
        ///RVU [1:1]
        ///Watchdog counter reload value
        ///update
        rvu: u1 = 0,
        ///WVU [2:2]
        ///Watchdog counter window value
        ///update
        wvu: u1 = 0,
        _unused3: u29 = 0,
    };
    ///Status register
    pub const sr = RegisterRW(sr_val, void).init(0x40003000 + 0xC);

    //////////////////////////
    ///WINR
    const winr_val = packed struct {
        ///WIN [0:11]
        ///Watchdog counter window
        ///value
        win: u12 = 4095,
        _unused12: u20 = 0,
    };
    ///Window register
    pub const winr = Register(winr_val).init(0x40003000 + 0x10);
};

///Window watchdog
pub const wwdg = struct {

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        ///T [0:6]
        ///7-bit counter
        t: u7 = 127,
        ///WDGA [7:7]
        ///Activation bit
        wdga: packed enum(u1) {
            ///Watchdog disabled
            disabled = 0,
            ///Watchdog enabled
            enabled = 1,
        } = .disabled,
        _unused8: u24 = 0,
    };
    ///Control register
    pub const cr = Register(cr_val).init(0x40002C00 + 0x0);

    //////////////////////////
    ///CFR
    const cfr_val = packed struct {
        ///W [0:6]
        ///7-bit window value
        w: u7 = 127,
        ///WDGTB [7:8]
        ///Timer base
        wdgtb: packed enum(u2) {
            ///Counter clock (PCLK1 div 4096) div 1
            div1 = 0,
            ///Counter clock (PCLK1 div 4096) div 2
            div2 = 1,
            ///Counter clock (PCLK1 div 4096) div 4
            div4 = 2,
            ///Counter clock (PCLK1 div 4096) div 8
            div8 = 3,
        } = .div1,
        ///EWI [9:9]
        ///Early wakeup interrupt
        ewi: u1 = 0,
        _unused10: u22 = 0,
    };
    ///Configuration register
    pub const cfr = Register(cfr_val).init(0x40002C00 + 0x4);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///EWIF [0:0]
        ///Early wakeup interrupt
        ///flag
        ewif: packed enum(u1) {
            ///The EWI Interrupt Service Routine has been triggered
            pending = 1,
            ///The EWI Interrupt Service Routine has been serviced
            finished = 0,
        } = .finished,
        _unused1: u31 = 0,
    };
    const sr_val_write = packed struct {
        ///EWIF [0:0]
        ///Early wakeup interrupt
        ///flag
        ewif: packed enum(u1) {
            ///The EWI Interrupt Service Routine has been serviced
            finished = 0,
        } = .finished,
        _unused1: u31 = 0,
    };
    ///Status register
    pub const sr = RegisterRW(sr_val_read, sr_val_write).init(0x40002C00 + 0x8);
};

///Advanced-timers
pub const tim1 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Counter is not stopped at update event
            disabled = 0,
            ///Counter stops counting at the next update event (clearing the CEN bit)
            enabled = 1,
        } = .disabled,
        ///DIR [4:4]
        ///Direction
        dir: packed enum(u1) {
            ///Counter used as upcounter
            up = 0,
            ///Counter used as downcounter
            down = 1,
        } = .up,
        ///CMS [5:6]
        ///Center-aligned mode
        ///selection
        cms: packed enum(u2) {
            ///The counter counts up or down depending on the direction bit
            edge_aligned = 0,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set only when the counter is counting down.
            center_aligned1 = 1,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set only when the counter is counting up.
            center_aligned2 = 2,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set both when the counter is counting up or down.
            center_aligned3 = 3,
        } = .edge_aligned,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40012C00 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///CCPC [0:0]
        ///Capture/compare preloaded
        ///control
        ccpc: u1 = 0,
        _unused1: u1 = 0,
        ///CCUS [2:2]
        ///Capture/compare control update
        ///selection
        ccus: u1 = 0,
        ///CCDS [3:3]
        ///Capture/compare DMA
        ///selection
        ccds: packed enum(u1) {
            ///CCx DMA request sent when CCx event occurs
            on_compare = 0,
            ///CCx DMA request sent when update event occurs
            on_update = 1,
        } = .on_compare,
        ///MMS [4:6]
        ///Master mode selection
        mms: packed enum(u3) {
            ///The UG bit from the TIMx_EGR register is used as trigger output
            reset = 0,
            ///The counter enable signal, CNT_EN, is used as trigger output
            enable = 1,
            ///The update event is selected as trigger output
            update = 2,
            ///The trigger output send a positive pulse when the CC1IF flag it to be set, as soon as a capture or a compare match occurred
            compare_pulse = 3,
            ///OC1REF signal is used as trigger output
            compare_oc1 = 4,
            ///OC2REF signal is used as trigger output
            compare_oc2 = 5,
            ///OC3REF signal is used as trigger output
            compare_oc3 = 6,
            ///OC4REF signal is used as trigger output
            compare_oc4 = 7,
        } = .reset,
        ///TI1S [7:7]
        ///TI1 selection
        ti1s: packed enum(u1) {
            ///The TIMx_CH1 pin is connected to TI1 input
            normal = 0,
            ///The TIMx_CH1, CH2, CH3 pins are connected to TI1 input
            xor = 1,
        } = .normal,
        ///OIS1 [8:8]
        ///Output Idle state 1
        ois1: u1 = 0,
        ///OIS1N [9:9]
        ///Output Idle state 1
        ois1n: u1 = 0,
        ///OIS2 [10:10]
        ///Output Idle state 2
        ois2: u1 = 0,
        ///OIS2N [11:11]
        ///Output Idle state 2
        ois2n: u1 = 0,
        ///OIS3 [12:12]
        ///Output Idle state 3
        ois3: u1 = 0,
        ///OIS3N [13:13]
        ///Output Idle state 3
        ois3n: u1 = 0,
        ///OIS4 [14:14]
        ///Output Idle state 4
        ois4: u1 = 0,
        _unused15: u17 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40012C00 + 0x4);

    //////////////////////////
    ///SMCR
    const smcr_val = packed struct {
        ///SMS [0:2]
        ///Slave mode selection
        sms: packed enum(u3) {
            ///Slave mode disabled - if CEN = ‘1 then the prescaler is clocked directly by the internal clock.
            disabled = 0,
            ///Encoder mode 1 - Counter counts up/down on TI2FP1 edge depending on TI1FP2 level.
            encoder_mode_1 = 1,
            ///Encoder mode 2 - Counter counts up/down on TI1FP2 edge depending on TI2FP1 level.
            encoder_mode_2 = 2,
            ///Encoder mode 3 - Counter counts up/down on both TI1FP1 and TI2FP2 edges depending on the level of the other input.
            encoder_mode_3 = 3,
            ///Reset Mode - Rising edge of the selected trigger input (TRGI) reinitializes the counter and generates an update of the registers.
            reset_mode = 4,
            ///Gated Mode - The counter clock is enabled when the trigger input (TRGI) is high. The counter stops (but is not reset) as soon as the trigger becomes low. Both start and stop of the counter are controlled.
            gated_mode = 5,
            ///Trigger Mode - The counter starts at a rising edge of the trigger TRGI (but it is not reset). Only the start of the counter is controlled.
            trigger_mode = 6,
            ///External Clock Mode 1 - Rising edges of the selected trigger (TRGI) clock the counter.
            ext_clock_mode = 7,
        } = .disabled,
        _unused3: u1 = 0,
        ///TS [4:6]
        ///Trigger selection
        ts: packed enum(u3) {
            ///Internal Trigger 0 (ITR0)
            itr0 = 0,
            ///Internal Trigger 1 (ITR1)
            itr1 = 1,
            ///Internal Trigger 2 (ITR2)
            itr2 = 2,
            ///TI1 Edge Detector (TI1F_ED)
            ti1f_ed = 4,
            ///Filtered Timer Input 1 (TI1FP1)
            ti1fp1 = 5,
            ///Filtered Timer Input 2 (TI2FP2)
            ti2fp2 = 6,
            ///External Trigger input (ETRF)
            etrf = 7,
        } = .itr0,
        ///MSM [7:7]
        ///Master/Slave mode
        msm: packed enum(u1) {
            ///No action
            no_sync = 0,
            ///The effect of an event on the trigger input (TRGI) is delayed to allow a perfect synchronization between the current timer and its slaves (through TRGO). It is useful if we want to synchronize several timers on a single external event.
            sync = 1,
        } = .no_sync,
        ///ETF [8:11]
        ///External trigger filter
        etf: packed enum(u4) {
            ///No filter, sampling is done at fDTS
            no_filter = 0,
            ///fSAMPLING=fCK_INT, N=2
            fck_int_n2 = 1,
            ///fSAMPLING=fCK_INT, N=4
            fck_int_n4 = 2,
            ///fSAMPLING=fCK_INT, N=8
            fck_int_n8 = 3,
            ///fSAMPLING=fDTS/2, N=6
            fdts_div2_n6 = 4,
            ///fSAMPLING=fDTS/2, N=8
            fdts_div2_n8 = 5,
            ///fSAMPLING=fDTS/4, N=6
            fdts_div4_n6 = 6,
            ///fSAMPLING=fDTS/4, N=8
            fdts_div4_n8 = 7,
            ///fSAMPLING=fDTS/8, N=6
            fdts_div8_n6 = 8,
            ///fSAMPLING=fDTS/8, N=8
            fdts_div8_n8 = 9,
            ///fSAMPLING=fDTS/16, N=5
            fdts_div16_n5 = 10,
            ///fSAMPLING=fDTS/16, N=6
            fdts_div16_n6 = 11,
            ///fSAMPLING=fDTS/16, N=8
            fdts_div16_n8 = 12,
            ///fSAMPLING=fDTS/32, N=5
            fdts_div32_n5 = 13,
            ///fSAMPLING=fDTS/32, N=6
            fdts_div32_n6 = 14,
            ///fSAMPLING=fDTS/32, N=8
            fdts_div32_n8 = 15,
        } = .no_filter,
        ///ETPS [12:13]
        ///External trigger prescaler
        etps: packed enum(u2) {
            ///Prescaler OFF
            div1 = 0,
            ///ETRP frequency divided by 2
            div2 = 1,
            ///ETRP frequency divided by 4
            div4 = 2,
            ///ETRP frequency divided by 8
            div8 = 3,
        } = .div1,
        ///ECE [14:14]
        ///External clock enable
        ece: packed enum(u1) {
            ///External clock mode 2 disabled
            disabled = 0,
            ///External clock mode 2 enabled. The counter is clocked by any active edge on the ETRF signal.
            enabled = 1,
        } = .disabled,
        ///ETP [15:15]
        ///External trigger polarity
        etp: packed enum(u1) {
            ///ETR is noninverted, active at high level or rising edge
            not_inverted = 0,
            ///ETR is inverted, active at low level or falling edge
            inverted = 1,
        } = .not_inverted,
        _unused16: u16 = 0,
    };
    ///slave mode control register
    pub const smcr = Register(smcr_val).init(0x40012C00 + 0x8);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: u1 = 0,
        ///CC2IE [2:2]
        ///Capture/Compare 2 interrupt
        ///enable
        cc2ie: u1 = 0,
        ///CC3IE [3:3]
        ///Capture/Compare 3 interrupt
        ///enable
        cc3ie: u1 = 0,
        ///CC4IE [4:4]
        ///Capture/Compare 4 interrupt
        ///enable
        cc4ie: packed enum(u1) {
            ///CCx interrupt disabled
            disabled = 0,
            ///CCx interrupt enabled
            enabled = 1,
        } = .disabled,
        ///COMIE [5:5]
        ///COM interrupt enable
        comie: u1 = 0,
        ///TIE [6:6]
        ///Trigger interrupt enable
        tie: packed enum(u1) {
            ///Trigger interrupt disabled
            disabled = 0,
            ///Trigger interrupt enabled
            enabled = 1,
        } = .disabled,
        ///BIE [7:7]
        ///Break interrupt enable
        bie: u1 = 0,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: packed enum(u1) {
            ///Update DMA request disabled
            disabled = 0,
            ///Update DMA request enabled
            enabled = 1,
        } = .disabled,
        ///CC1DE [9:9]
        ///Capture/Compare 1 DMA request
        ///enable
        cc1de: u1 = 0,
        ///CC2DE [10:10]
        ///Capture/Compare 2 DMA request
        ///enable
        cc2de: u1 = 0,
        ///CC3DE [11:11]
        ///Capture/Compare 3 DMA request
        ///enable
        cc3de: u1 = 0,
        ///CC4DE [12:12]
        ///Capture/Compare 4 DMA request
        ///enable
        cc4de: packed enum(u1) {
            ///CCx DMA request disabled
            disabled = 0,
            ///CCx DMA request enabled
            enabled = 1,
        } = .disabled,
        ///COMDE [13:13]
        ///COM DMA request enable
        comde: u1 = 0,
        ///TDE [14:14]
        ///Trigger DMA request enable
        tde: packed enum(u1) {
            ///Trigger DMA request disabled
            disabled = 0,
            ///Trigger DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused15: u17 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40012C00 + 0xC);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: u1 = 0,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        ///CC2IF [2:2]
        ///Capture/Compare 2 interrupt
        ///flag
        cc2if: u1 = 0,
        ///CC3IF [3:3]
        ///Capture/Compare 3 interrupt
        ///flag
        cc3if: u1 = 0,
        ///CC4IF [4:4]
        ///Capture/Compare 4 interrupt
        ///flag
        cc4if: packed enum(u1) {
            ///If CC1 is an output: The content of the counter TIMx_CNT matches the content of the TIMx_CCR1 register. If CC1 is an input: The counter value has been captured in TIMx_CCR1 register.
            match = 1,
            _zero = 0,
        } = ._zero,
        ///COMIF [5:5]
        ///COM interrupt flag
        comif: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: packed enum(u1) {
            ///No trigger event occurred
            no_trigger = 0,
            ///Trigger interrupt pending
            trigger = 1,
        } = .no_trigger,
        ///BIF [7:7]
        ///Break interrupt flag
        bif: u1 = 0,
        _unused8: u1 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        ///CC2OF [10:10]
        ///Capture/compare 2 overcapture
        ///flag
        cc2of: u1 = 0,
        ///CC3OF [11:11]
        ///Capture/Compare 3 overcapture
        ///flag
        cc3of: u1 = 0,
        ///CC4OF [12:12]
        ///Capture/Compare 4 overcapture
        ///flag
        cc4of: packed enum(u1) {
            ///The counter value has been captured in TIMx_CCRx register while CCxIF flag was already set
            overcapture = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u19 = 0,
    };
    const sr_val_write = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: u1 = 0,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        ///CC2IF [2:2]
        ///Capture/Compare 2 interrupt
        ///flag
        cc2if: u1 = 0,
        ///CC3IF [3:3]
        ///Capture/Compare 3 interrupt
        ///flag
        cc3if: u1 = 0,
        ///CC4IF [4:4]
        ///Capture/Compare 4 interrupt
        ///flag
        cc4if: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        ///COMIF [5:5]
        ///COM interrupt flag
        comif: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        ///BIF [7:7]
        ///Break interrupt flag
        bif: u1 = 0,
        _unused8: u1 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        ///CC2OF [10:10]
        ///Capture/compare 2 overcapture
        ///flag
        cc2of: u1 = 0,
        ///CC3OF [11:11]
        ///Capture/Compare 3 overcapture
        ///flag
        cc3of: u1 = 0,
        ///CC4OF [12:12]
        ///Capture/Compare 4 overcapture
        ///flag
        cc4of: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        _unused13: u19 = 0,
    };
    ///status register
    pub const sr = RegisterRW(sr_val_read, sr_val_write).init(0x40012C00 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        ///CC2G [2:2]
        ///Capture/compare 2
        ///generation
        cc2g: u1 = 0,
        ///CC3G [3:3]
        ///Capture/compare 3
        ///generation
        cc3g: u1 = 0,
        ///CC4G [4:4]
        ///Capture/compare 4
        ///generation
        cc4g: u1 = 0,
        ///COMG [5:5]
        ///Capture/Compare control update
        ///generation
        comg: u1 = 0,
        ///TG [6:6]
        ///Trigger generation
        tg: u1 = 0,
        ///BG [7:7]
        ///Break generation
        bg: u1 = 0,
        _unused8: u24 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40012C00 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: packed enum(u2) {
            ///CC1 channel is configured as output
            output = 0,
        } = .output,
        ///OC1FE [2:2]
        ///Output Compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output Compare 1 preload
        ///enable
        oc1pe: packed enum(u1) {
            ///Preload register on CCR1 disabled. New values written to CCR1 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR1 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC1M [4:6]
        ///Output Compare 1 mode
        oc1m: u3 = 0,
        ///OC1CE [7:7]
        ///Output Compare 1 clear
        ///enable
        oc1ce: u1 = 0,
        ///CC2S [8:9]
        ///Capture/Compare 2
        ///selection
        cc2s: packed enum(u2) {
            ///CC2 channel is configured as output
            output = 0,
        } = .output,
        ///OC2FE [10:10]
        ///Output Compare 2 fast
        ///enable
        oc2fe: u1 = 0,
        ///OC2PE [11:11]
        ///Output Compare 2 preload
        ///enable
        oc2pe: packed enum(u1) {
            ///Preload register on CCR2 disabled. New values written to CCR2 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR2 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC2M [12:14]
        ///Output Compare 2 mode
        oc2m: packed enum(u3) {
            ///The comparison between the output compare register TIMx_CCRy and the counter TIMx_CNT has no effect on the outputs
            frozen = 0,
            ///Set channel to active level on match. OCyREF signal is forced high when the counter matches the capture/compare register
            active_on_match = 1,
            ///Set channel to inactive level on match. OCyREF signal is forced low when the counter matches the capture/compare register
            inactive_on_match = 2,
            ///OCyREF toggles when TIMx_CNT=TIMx_CCRy
            toggle = 3,
            ///OCyREF is forced low
            force_inactive = 4,
            ///OCyREF is forced high
            force_active = 5,
            ///In upcounting, channel is active as long as TIMx_CNT<TIMx_CCRy else inactive. In downcounting, channel is inactive as long as TIMx_CNT>TIMx_CCRy else active
            pwm_mode1 = 6,
            ///Inversely to PwmMode1
            pwm_mode2 = 7,
        } = .frozen,
        ///OC2CE [15:15]
        ///Output Compare 2 clear
        ///enable
        oc2ce: u1 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40012C00 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: packed enum(u2) {
            ///CC1 channel is configured as input, IC1 is mapped on TI1
            ti1 = 1,
            ///CC1 channel is configured as input, IC1 is mapped on TI2
            ti2 = 2,
            ///CC1 channel is configured as input, IC1 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: packed enum(u4) {
            ///No filter, sampling is done at fDTS
            no_filter = 0,
            ///fSAMPLING=fCK_INT, N=2
            fck_int_n2 = 1,
            ///fSAMPLING=fCK_INT, N=4
            fck_int_n4 = 2,
            ///fSAMPLING=fCK_INT, N=8
            fck_int_n8 = 3,
            ///fSAMPLING=fDTS/2, N=6
            fdts_div2_n6 = 4,
            ///fSAMPLING=fDTS/2, N=8
            fdts_div2_n8 = 5,
            ///fSAMPLING=fDTS/4, N=6
            fdts_div4_n6 = 6,
            ///fSAMPLING=fDTS/4, N=8
            fdts_div4_n8 = 7,
            ///fSAMPLING=fDTS/8, N=6
            fdts_div8_n6 = 8,
            ///fSAMPLING=fDTS/8, N=8
            fdts_div8_n8 = 9,
            ///fSAMPLING=fDTS/16, N=5
            fdts_div16_n5 = 10,
            ///fSAMPLING=fDTS/16, N=6
            fdts_div16_n6 = 11,
            ///fSAMPLING=fDTS/16, N=8
            fdts_div16_n8 = 12,
            ///fSAMPLING=fDTS/32, N=5
            fdts_div32_n5 = 13,
            ///fSAMPLING=fDTS/32, N=6
            fdts_div32_n6 = 14,
            ///fSAMPLING=fDTS/32, N=8
            fdts_div32_n8 = 15,
        } = .no_filter,
        ///CC2S [8:9]
        ///Capture/Compare 2
        ///selection
        cc2s: packed enum(u2) {
            ///CC2 channel is configured as input, IC2 is mapped on TI2
            ti2 = 1,
            ///CC2 channel is configured as input, IC2 is mapped on TI1
            ti1 = 2,
            ///CC2 channel is configured as input, IC2 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC2PSC [10:11]
        ///Input capture 2 prescaler
        ic2psc: u2 = 0,
        ///IC2F [12:15]
        ///Input capture 2 filter
        ic2f: u4 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 1 (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40012C00 + 0x18);

    //////////////////////////
    ///CCMR2_Output
    const ccmr2_output_val = packed struct {
        ///CC3S [0:1]
        ///Capture/Compare 3
        ///selection
        cc3s: packed enum(u2) {
            ///CC3 channel is configured as output
            output = 0,
        } = .output,
        ///OC3FE [2:2]
        ///Output compare 3 fast
        ///enable
        oc3fe: u1 = 0,
        ///OC3PE [3:3]
        ///Output compare 3 preload
        ///enable
        oc3pe: packed enum(u1) {
            ///Preload register on CCR3 disabled. New values written to CCR3 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR3 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC3M [4:6]
        ///Output compare 3 mode
        oc3m: u3 = 0,
        ///OC3CE [7:7]
        ///Output compare 3 clear
        ///enable
        oc3ce: u1 = 0,
        ///CC4S [8:9]
        ///Capture/Compare 4
        ///selection
        cc4s: packed enum(u2) {
            ///CC4 channel is configured as output
            output = 0,
        } = .output,
        ///OC4FE [10:10]
        ///Output compare 4 fast
        ///enable
        oc4fe: u1 = 0,
        ///OC4PE [11:11]
        ///Output compare 4 preload
        ///enable
        oc4pe: packed enum(u1) {
            ///Preload register on CCR4 disabled. New values written to CCR4 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR4 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC4M [12:14]
        ///Output compare 4 mode
        oc4m: packed enum(u3) {
            ///The comparison between the output compare register TIMx_CCRy and the counter TIMx_CNT has no effect on the outputs
            frozen = 0,
            ///Set channel to active level on match. OCyREF signal is forced high when the counter matches the capture/compare register
            active_on_match = 1,
            ///Set channel to inactive level on match. OCyREF signal is forced low when the counter matches the capture/compare register
            inactive_on_match = 2,
            ///OCyREF toggles when TIMx_CNT=TIMx_CCRy
            toggle = 3,
            ///OCyREF is forced low
            force_inactive = 4,
            ///OCyREF is forced high
            force_active = 5,
            ///In upcounting, channel is active as long as TIMx_CNT<TIMx_CCRy else inactive. In downcounting, channel is inactive as long as TIMx_CNT>TIMx_CCRy else active
            pwm_mode1 = 6,
            ///Inversely to PwmMode1
            pwm_mode2 = 7,
        } = .frozen,
        ///OC4CE [15:15]
        ///Output compare 4 clear
        ///enable
        oc4ce: u1 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr2_output = Register(ccmr2_output_val).init(0x40012C00 + 0x1C);

    //////////////////////////
    ///CCMR2_Input
    const ccmr2_input_val = packed struct {
        ///CC3S [0:1]
        ///Capture/compare 3
        ///selection
        cc3s: packed enum(u2) {
            ///CC3 channel is configured as input, IC3 is mapped on TI3
            ti3 = 1,
            ///CC3 channel is configured as input, IC3 is mapped on TI4
            ti4 = 2,
            ///CC3 channel is configured as input, IC3 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC3PSC [2:3]
        ///Input capture 3 prescaler
        ic3psc: u2 = 0,
        ///IC3F [4:7]
        ///Input capture 3 filter
        ic3f: u4 = 0,
        ///CC4S [8:9]
        ///Capture/Compare 4
        ///selection
        cc4s: packed enum(u2) {
            ///CC4 channel is configured as input, IC4 is mapped on TI4
            ti4 = 1,
            ///CC4 channel is configured as input, IC4 is mapped on TI3
            ti3 = 2,
            ///CC4 channel is configured as input, IC4 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC4PSC [10:11]
        ///Input capture 4 prescaler
        ic4psc: u2 = 0,
        ///IC4F [12:15]
        ///Input capture 4 filter
        ic4f: u4 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 2 (input
    ///mode)
    pub const ccmr2_input = Register(ccmr2_input_val).init(0x40012C00 + 0x1C);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        ///CC1NE [2:2]
        ///Capture/Compare 1 complementary output
        ///enable
        cc1ne: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        ///CC2E [4:4]
        ///Capture/Compare 2 output
        ///enable
        cc2e: u1 = 0,
        ///CC2P [5:5]
        ///Capture/Compare 2 output
        ///Polarity
        cc2p: u1 = 0,
        ///CC2NE [6:6]
        ///Capture/Compare 2 complementary output
        ///enable
        cc2ne: u1 = 0,
        ///CC2NP [7:7]
        ///Capture/Compare 2 output
        ///Polarity
        cc2np: u1 = 0,
        ///CC3E [8:8]
        ///Capture/Compare 3 output
        ///enable
        cc3e: u1 = 0,
        ///CC3P [9:9]
        ///Capture/Compare 3 output
        ///Polarity
        cc3p: u1 = 0,
        ///CC3NE [10:10]
        ///Capture/Compare 3 complementary output
        ///enable
        cc3ne: u1 = 0,
        ///CC3NP [11:11]
        ///Capture/Compare 3 output
        ///Polarity
        cc3np: u1 = 0,
        ///CC4E [12:12]
        ///Capture/Compare 4 output
        ///enable
        cc4e: u1 = 0,
        ///CC4P [13:13]
        ///Capture/Compare 3 output
        ///Polarity
        cc4p: u1 = 0,
        _unused14: u18 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40012C00 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40012C00 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40012C00 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40012C00 + 0x2C);

    //////////////////////////
    ///RCR
    const rcr_val = packed struct {
        ///REP [0:7]
        ///Repetition counter value
        rep: u8 = 0,
        _unused8: u24 = 0,
    };
    ///repetition counter register
    pub const rcr = Register(rcr_val).init(0x40012C00 + 0x30);

    //////////////////////////
    ///CCR%s
    const ccr_val = packed struct {
        ///CCR [0:15]
        ///Capture/Compare 1 value
        ccr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr = Register(ccr_val).initRange(0x40012C00 + 0x34, 4, 4);

    //////////////////////////
    ///BDTR
    const bdtr_val = packed struct {
        ///DTG [0:7]
        ///Dead-time generator setup
        dtg: u8 = 0,
        ///LOCK [8:9]
        ///Lock configuration
        lock: u2 = 0,
        ///OSSI [10:10]
        ///Off-state selection for Idle
        ///mode
        ossi: u1 = 0,
        ///OSSR [11:11]
        ///Off-state selection for Run
        ///mode
        ossr: u1 = 0,
        ///BKE [12:12]
        ///Break enable
        bke: u1 = 0,
        ///BKP [13:13]
        ///Break polarity
        bkp: u1 = 0,
        ///AOE [14:14]
        ///Automatic output enable
        aoe: u1 = 0,
        ///MOE [15:15]
        ///Main output enable
        moe: u1 = 0,
        _unused16: u16 = 0,
    };
    ///break and dead-time register
    pub const bdtr = Register(bdtr_val).init(0x40012C00 + 0x44);

    //////////////////////////
    ///DCR
    const dcr_val = packed struct {
        ///DBA [0:4]
        ///DMA base address
        dba: u5 = 0,
        _unused5: u3 = 0,
        ///DBL [8:12]
        ///DMA burst length
        dbl: u5 = 0,
        _unused13: u19 = 0,
    };
    ///DMA control register
    pub const dcr = Register(dcr_val).init(0x40012C00 + 0x48);

    //////////////////////////
    ///DMAR
    const dmar_val = packed struct {
        ///DMAB [0:15]
        ///DMA register for burst
        ///accesses
        dmab: u16 = 0,
        _unused16: u16 = 0,
    };
    ///DMA address for full transfer
    pub const dmar = Register(dmar_val).init(0x40012C00 + 0x4C);
};

///General-purpose-timers
pub const tim3 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Counter is not stopped at update event
            disabled = 0,
            ///Counter stops counting at the next update event (clearing the CEN bit)
            enabled = 1,
        } = .disabled,
        ///DIR [4:4]
        ///Direction
        dir: packed enum(u1) {
            ///Counter used as upcounter
            up = 0,
            ///Counter used as downcounter
            down = 1,
        } = .up,
        ///CMS [5:6]
        ///Center-aligned mode
        ///selection
        cms: packed enum(u2) {
            ///The counter counts up or down depending on the direction bit
            edge_aligned = 0,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set only when the counter is counting down.
            center_aligned1 = 1,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set only when the counter is counting up.
            center_aligned2 = 2,
            ///The counter counts up and down alternatively. Output compare interrupt flags are set both when the counter is counting up or down.
            center_aligned3 = 3,
        } = .edge_aligned,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40000400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u3 = 0,
        ///CCDS [3:3]
        ///Capture/compare DMA
        ///selection
        ccds: packed enum(u1) {
            ///CCx DMA request sent when CCx event occurs
            on_compare = 0,
            ///CCx DMA request sent when update event occurs
            on_update = 1,
        } = .on_compare,
        ///MMS [4:6]
        ///Master mode selection
        mms: packed enum(u3) {
            ///The UG bit from the TIMx_EGR register is used as trigger output
            reset = 0,
            ///The counter enable signal, CNT_EN, is used as trigger output
            enable = 1,
            ///The update event is selected as trigger output
            update = 2,
            ///The trigger output send a positive pulse when the CC1IF flag it to be set, as soon as a capture or a compare match occurred
            compare_pulse = 3,
            ///OC1REF signal is used as trigger output
            compare_oc1 = 4,
            ///OC2REF signal is used as trigger output
            compare_oc2 = 5,
            ///OC3REF signal is used as trigger output
            compare_oc3 = 6,
            ///OC4REF signal is used as trigger output
            compare_oc4 = 7,
        } = .reset,
        ///TI1S [7:7]
        ///TI1 selection
        ti1s: packed enum(u1) {
            ///The TIMx_CH1 pin is connected to TI1 input
            normal = 0,
            ///The TIMx_CH1, CH2, CH3 pins are connected to TI1 input
            xor = 1,
        } = .normal,
        _unused8: u24 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40000400 + 0x4);

    //////////////////////////
    ///SMCR
    const smcr_val = packed struct {
        ///SMS [0:2]
        ///Slave mode selection
        sms: packed enum(u3) {
            ///Slave mode disabled - if CEN = ‘1 then the prescaler is clocked directly by the internal clock.
            disabled = 0,
            ///Encoder mode 1 - Counter counts up/down on TI2FP1 edge depending on TI1FP2 level.
            encoder_mode_1 = 1,
            ///Encoder mode 2 - Counter counts up/down on TI1FP2 edge depending on TI2FP1 level.
            encoder_mode_2 = 2,
            ///Encoder mode 3 - Counter counts up/down on both TI1FP1 and TI2FP2 edges depending on the level of the other input.
            encoder_mode_3 = 3,
            ///Reset Mode - Rising edge of the selected trigger input (TRGI) reinitializes the counter and generates an update of the registers.
            reset_mode = 4,
            ///Gated Mode - The counter clock is enabled when the trigger input (TRGI) is high. The counter stops (but is not reset) as soon as the trigger becomes low. Both start and stop of the counter are controlled.
            gated_mode = 5,
            ///Trigger Mode - The counter starts at a rising edge of the trigger TRGI (but it is not reset). Only the start of the counter is controlled.
            trigger_mode = 6,
            ///External Clock Mode 1 - Rising edges of the selected trigger (TRGI) clock the counter.
            ext_clock_mode = 7,
        } = .disabled,
        _unused3: u1 = 0,
        ///TS [4:6]
        ///Trigger selection
        ts: packed enum(u3) {
            ///Internal Trigger 0 (ITR0)
            itr0 = 0,
            ///Internal Trigger 1 (ITR1)
            itr1 = 1,
            ///Internal Trigger 2 (ITR2)
            itr2 = 2,
            ///TI1 Edge Detector (TI1F_ED)
            ti1f_ed = 4,
            ///Filtered Timer Input 1 (TI1FP1)
            ti1fp1 = 5,
            ///Filtered Timer Input 2 (TI2FP2)
            ti2fp2 = 6,
            ///External Trigger input (ETRF)
            etrf = 7,
        } = .itr0,
        ///MSM [7:7]
        ///Master/Slave mode
        msm: packed enum(u1) {
            ///No action
            no_sync = 0,
            ///The effect of an event on the trigger input (TRGI) is delayed to allow a perfect synchronization between the current timer and its slaves (through TRGO). It is useful if we want to synchronize several timers on a single external event.
            sync = 1,
        } = .no_sync,
        ///ETF [8:11]
        ///External trigger filter
        etf: packed enum(u4) {
            ///No filter, sampling is done at fDTS
            no_filter = 0,
            ///fSAMPLING=fCK_INT, N=2
            fck_int_n2 = 1,
            ///fSAMPLING=fCK_INT, N=4
            fck_int_n4 = 2,
            ///fSAMPLING=fCK_INT, N=8
            fck_int_n8 = 3,
            ///fSAMPLING=fDTS/2, N=6
            fdts_div2_n6 = 4,
            ///fSAMPLING=fDTS/2, N=8
            fdts_div2_n8 = 5,
            ///fSAMPLING=fDTS/4, N=6
            fdts_div4_n6 = 6,
            ///fSAMPLING=fDTS/4, N=8
            fdts_div4_n8 = 7,
            ///fSAMPLING=fDTS/8, N=6
            fdts_div8_n6 = 8,
            ///fSAMPLING=fDTS/8, N=8
            fdts_div8_n8 = 9,
            ///fSAMPLING=fDTS/16, N=5
            fdts_div16_n5 = 10,
            ///fSAMPLING=fDTS/16, N=6
            fdts_div16_n6 = 11,
            ///fSAMPLING=fDTS/16, N=8
            fdts_div16_n8 = 12,
            ///fSAMPLING=fDTS/32, N=5
            fdts_div32_n5 = 13,
            ///fSAMPLING=fDTS/32, N=6
            fdts_div32_n6 = 14,
            ///fSAMPLING=fDTS/32, N=8
            fdts_div32_n8 = 15,
        } = .no_filter,
        ///ETPS [12:13]
        ///External trigger prescaler
        etps: packed enum(u2) {
            ///Prescaler OFF
            div1 = 0,
            ///ETRP frequency divided by 2
            div2 = 1,
            ///ETRP frequency divided by 4
            div4 = 2,
            ///ETRP frequency divided by 8
            div8 = 3,
        } = .div1,
        ///ECE [14:14]
        ///External clock enable
        ece: packed enum(u1) {
            ///External clock mode 2 disabled
            disabled = 0,
            ///External clock mode 2 enabled. The counter is clocked by any active edge on the ETRF signal.
            enabled = 1,
        } = .disabled,
        ///ETP [15:15]
        ///External trigger polarity
        etp: packed enum(u1) {
            ///ETR is noninverted, active at high level or rising edge
            not_inverted = 0,
            ///ETR is inverted, active at low level or falling edge
            inverted = 1,
        } = .not_inverted,
        _unused16: u16 = 0,
    };
    ///slave mode control register
    pub const smcr = Register(smcr_val).init(0x40000400 + 0x8);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: u1 = 0,
        ///CC2IE [2:2]
        ///Capture/Compare 2 interrupt
        ///enable
        cc2ie: u1 = 0,
        ///CC3IE [3:3]
        ///Capture/Compare 3 interrupt
        ///enable
        cc3ie: u1 = 0,
        ///CC4IE [4:4]
        ///Capture/Compare 4 interrupt
        ///enable
        cc4ie: packed enum(u1) {
            ///CCx interrupt disabled
            disabled = 0,
            ///CCx interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused5: u1 = 0,
        ///TIE [6:6]
        ///Trigger interrupt enable
        tie: packed enum(u1) {
            ///Trigger interrupt disabled
            disabled = 0,
            ///Trigger interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: packed enum(u1) {
            ///Update DMA request disabled
            disabled = 0,
            ///Update DMA request enabled
            enabled = 1,
        } = .disabled,
        ///CC1DE [9:9]
        ///Capture/Compare 1 DMA request
        ///enable
        cc1de: u1 = 0,
        ///CC2DE [10:10]
        ///Capture/Compare 2 DMA request
        ///enable
        cc2de: u1 = 0,
        ///CC3DE [11:11]
        ///Capture/Compare 3 DMA request
        ///enable
        cc3de: u1 = 0,
        ///CC4DE [12:12]
        ///Capture/Compare 4 DMA request
        ///enable
        cc4de: packed enum(u1) {
            ///CCx DMA request disabled
            disabled = 0,
            ///CCx DMA request enabled
            enabled = 1,
        } = .disabled,
        ///COMDE [13:13]
        ///COM DMA request enable
        comde: u1 = 0,
        ///TDE [14:14]
        ///Trigger DMA request enable
        tde: packed enum(u1) {
            ///Trigger DMA request disabled
            disabled = 0,
            ///Trigger DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused15: u17 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40000400 + 0xC);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: u1 = 0,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        ///CC2IF [2:2]
        ///Capture/Compare 2 interrupt
        ///flag
        cc2if: u1 = 0,
        ///CC3IF [3:3]
        ///Capture/Compare 3 interrupt
        ///flag
        cc3if: u1 = 0,
        ///CC4IF [4:4]
        ///Capture/Compare 4 interrupt
        ///flag
        cc4if: packed enum(u1) {
            ///If CC1 is an output: The content of the counter TIMx_CNT matches the content of the TIMx_CCR1 register. If CC1 is an input: The counter value has been captured in TIMx_CCR1 register.
            match = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: packed enum(u1) {
            ///No trigger event occurred
            no_trigger = 0,
            ///Trigger interrupt pending
            trigger = 1,
        } = .no_trigger,
        _unused7: u2 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        ///CC2OF [10:10]
        ///Capture/compare 2 overcapture
        ///flag
        cc2of: u1 = 0,
        ///CC3OF [11:11]
        ///Capture/Compare 3 overcapture
        ///flag
        cc3of: u1 = 0,
        ///CC4OF [12:12]
        ///Capture/Compare 4 overcapture
        ///flag
        cc4of: packed enum(u1) {
            ///The counter value has been captured in TIMx_CCRx register while CCxIF flag was already set
            overcapture = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u19 = 0,
    };
    const sr_val_write = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: u1 = 0,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        ///CC2IF [2:2]
        ///Capture/Compare 2 interrupt
        ///flag
        cc2if: u1 = 0,
        ///CC3IF [3:3]
        ///Capture/Compare 3 interrupt
        ///flag
        cc3if: u1 = 0,
        ///CC4IF [4:4]
        ///Capture/Compare 4 interrupt
        ///flag
        cc4if: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        _unused5: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        _unused7: u2 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        ///CC2OF [10:10]
        ///Capture/compare 2 overcapture
        ///flag
        cc2of: u1 = 0,
        ///CC3OF [11:11]
        ///Capture/Compare 3 overcapture
        ///flag
        cc3of: u1 = 0,
        ///CC4OF [12:12]
        ///Capture/Compare 4 overcapture
        ///flag
        cc4of: packed enum(u1) {
            ///Clear flag
            clear = 0,
        } = .clear,
        _unused13: u19 = 0,
    };
    ///status register
    pub const sr = RegisterRW(sr_val_read, sr_val_write).init(0x40000400 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        ///CC2G [2:2]
        ///Capture/compare 2
        ///generation
        cc2g: u1 = 0,
        ///CC3G [3:3]
        ///Capture/compare 3
        ///generation
        cc3g: u1 = 0,
        ///CC4G [4:4]
        ///Capture/compare 4
        ///generation
        cc4g: u1 = 0,
        _unused5: u1 = 0,
        ///TG [6:6]
        ///Trigger generation
        tg: u1 = 0,
        _unused7: u25 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40000400 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: packed enum(u2) {
            ///CC1 channel is configured as output
            output = 0,
        } = .output,
        ///OC1FE [2:2]
        ///Output compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output compare 1 preload
        ///enable
        oc1pe: packed enum(u1) {
            ///Preload register on CCR1 disabled. New values written to CCR1 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR1 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC1M [4:6]
        ///Output compare 1 mode
        oc1m: u3 = 0,
        ///OC1CE [7:7]
        ///Output compare 1 clear
        ///enable
        oc1ce: u1 = 0,
        ///CC2S [8:9]
        ///Capture/Compare 2
        ///selection
        cc2s: packed enum(u2) {
            ///CC2 channel is configured as output
            output = 0,
        } = .output,
        ///OC2FE [10:10]
        ///Output compare 2 fast
        ///enable
        oc2fe: u1 = 0,
        ///OC2PE [11:11]
        ///Output compare 2 preload
        ///enable
        oc2pe: packed enum(u1) {
            ///Preload register on CCR2 disabled. New values written to CCR2 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR2 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC2M [12:14]
        ///Output compare 2 mode
        oc2m: packed enum(u3) {
            ///The comparison between the output compare register TIMx_CCRy and the counter TIMx_CNT has no effect on the outputs
            frozen = 0,
            ///Set channel to active level on match. OCyREF signal is forced high when the counter matches the capture/compare register
            active_on_match = 1,
            ///Set channel to inactive level on match. OCyREF signal is forced low when the counter matches the capture/compare register
            inactive_on_match = 2,
            ///OCyREF toggles when TIMx_CNT=TIMx_CCRy
            toggle = 3,
            ///OCyREF is forced low
            force_inactive = 4,
            ///OCyREF is forced high
            force_active = 5,
            ///In upcounting, channel is active as long as TIMx_CNT<TIMx_CCRy else inactive. In downcounting, channel is inactive as long as TIMx_CNT>TIMx_CCRy else active
            pwm_mode1 = 6,
            ///Inversely to PwmMode1
            pwm_mode2 = 7,
        } = .frozen,
        ///OC2CE [15:15]
        ///Output compare 2 clear
        ///enable
        oc2ce: u1 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 1 (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40000400 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: packed enum(u2) {
            ///CC1 channel is configured as input, IC1 is mapped on TI1
            ti1 = 1,
            ///CC1 channel is configured as input, IC1 is mapped on TI2
            ti2 = 2,
            ///CC1 channel is configured as input, IC1 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: packed enum(u4) {
            ///No filter, sampling is done at fDTS
            no_filter = 0,
            ///fSAMPLING=fCK_INT, N=2
            fck_int_n2 = 1,
            ///fSAMPLING=fCK_INT, N=4
            fck_int_n4 = 2,
            ///fSAMPLING=fCK_INT, N=8
            fck_int_n8 = 3,
            ///fSAMPLING=fDTS/2, N=6
            fdts_div2_n6 = 4,
            ///fSAMPLING=fDTS/2, N=8
            fdts_div2_n8 = 5,
            ///fSAMPLING=fDTS/4, N=6
            fdts_div4_n6 = 6,
            ///fSAMPLING=fDTS/4, N=8
            fdts_div4_n8 = 7,
            ///fSAMPLING=fDTS/8, N=6
            fdts_div8_n6 = 8,
            ///fSAMPLING=fDTS/8, N=8
            fdts_div8_n8 = 9,
            ///fSAMPLING=fDTS/16, N=5
            fdts_div16_n5 = 10,
            ///fSAMPLING=fDTS/16, N=6
            fdts_div16_n6 = 11,
            ///fSAMPLING=fDTS/16, N=8
            fdts_div16_n8 = 12,
            ///fSAMPLING=fDTS/32, N=5
            fdts_div32_n5 = 13,
            ///fSAMPLING=fDTS/32, N=6
            fdts_div32_n6 = 14,
            ///fSAMPLING=fDTS/32, N=8
            fdts_div32_n8 = 15,
        } = .no_filter,
        ///CC2S [8:9]
        ///Capture/compare 2
        ///selection
        cc2s: packed enum(u2) {
            ///CC2 channel is configured as input, IC2 is mapped on TI2
            ti2 = 1,
            ///CC2 channel is configured as input, IC2 is mapped on TI1
            ti1 = 2,
            ///CC2 channel is configured as input, IC2 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC2PSC [10:11]
        ///Input capture 2 prescaler
        ic2psc: u2 = 0,
        ///IC2F [12:15]
        ///Input capture 2 filter
        ic2f: u4 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 1 (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40000400 + 0x18);

    //////////////////////////
    ///CCMR2_Output
    const ccmr2_output_val = packed struct {
        ///CC3S [0:1]
        ///Capture/Compare 3
        ///selection
        cc3s: packed enum(u2) {
            ///CC3 channel is configured as output
            output = 0,
        } = .output,
        ///OC3FE [2:2]
        ///Output compare 3 fast
        ///enable
        oc3fe: u1 = 0,
        ///OC3PE [3:3]
        ///Output compare 3 preload
        ///enable
        oc3pe: packed enum(u1) {
            ///Preload register on CCR3 disabled. New values written to CCR3 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR3 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC3M [4:6]
        ///Output compare 3 mode
        oc3m: u3 = 0,
        ///OC3CE [7:7]
        ///Output compare 3 clear
        ///enable
        oc3ce: u1 = 0,
        ///CC4S [8:9]
        ///Capture/Compare 4
        ///selection
        cc4s: packed enum(u2) {
            ///CC4 channel is configured as output
            output = 0,
        } = .output,
        ///OC4FE [10:10]
        ///Output compare 4 fast
        ///enable
        oc4fe: u1 = 0,
        ///OC4PE [11:11]
        ///Output compare 4 preload
        ///enable
        oc4pe: packed enum(u1) {
            ///Preload register on CCR4 disabled. New values written to CCR4 are taken into account immediately
            disabled = 0,
            ///Preload register on CCR4 enabled. Preload value is loaded into active register on each update event
            enabled = 1,
        } = .disabled,
        ///OC4M [12:14]
        ///Output compare 4 mode
        oc4m: packed enum(u3) {
            ///The comparison between the output compare register TIMx_CCRy and the counter TIMx_CNT has no effect on the outputs
            frozen = 0,
            ///Set channel to active level on match. OCyREF signal is forced high when the counter matches the capture/compare register
            active_on_match = 1,
            ///Set channel to inactive level on match. OCyREF signal is forced low when the counter matches the capture/compare register
            inactive_on_match = 2,
            ///OCyREF toggles when TIMx_CNT=TIMx_CCRy
            toggle = 3,
            ///OCyREF is forced low
            force_inactive = 4,
            ///OCyREF is forced high
            force_active = 5,
            ///In upcounting, channel is active as long as TIMx_CNT<TIMx_CCRy else inactive. In downcounting, channel is inactive as long as TIMx_CNT>TIMx_CCRy else active
            pwm_mode1 = 6,
            ///Inversely to PwmMode1
            pwm_mode2 = 7,
        } = .frozen,
        ///OC4CE [15:15]
        ///Output compare 4 clear
        ///enable
        oc4ce: u1 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 2 (output
    ///mode)
    pub const ccmr2_output = Register(ccmr2_output_val).init(0x40000400 + 0x1C);

    //////////////////////////
    ///CCMR2_Input
    const ccmr2_input_val = packed struct {
        ///CC3S [0:1]
        ///Capture/Compare 3
        ///selection
        cc3s: packed enum(u2) {
            ///CC3 channel is configured as input, IC3 is mapped on TI3
            ti3 = 1,
            ///CC3 channel is configured as input, IC3 is mapped on TI4
            ti4 = 2,
            ///CC3 channel is configured as input, IC3 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC3PSC [2:3]
        ///Input capture 3 prescaler
        ic3psc: u2 = 0,
        ///IC3F [4:7]
        ///Input capture 3 filter
        ic3f: u4 = 0,
        ///CC4S [8:9]
        ///Capture/Compare 4
        ///selection
        cc4s: packed enum(u2) {
            ///CC4 channel is configured as input, IC4 is mapped on TI4
            ti4 = 1,
            ///CC4 channel is configured as input, IC4 is mapped on TI3
            ti3 = 2,
            ///CC4 channel is configured as input, IC4 is mapped on TRC
            trc = 3,
            _zero = 0,
        } = ._zero,
        ///IC4PSC [10:11]
        ///Input capture 4 prescaler
        ic4psc: u2 = 0,
        ///IC4F [12:15]
        ///Input capture 4 filter
        ic4f: u4 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 2 (input
    ///mode)
    pub const ccmr2_input = Register(ccmr2_input_val).init(0x40000400 + 0x1C);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        _unused2: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        ///CC2E [4:4]
        ///Capture/Compare 2 output
        ///enable
        cc2e: u1 = 0,
        ///CC2P [5:5]
        ///Capture/Compare 2 output
        ///Polarity
        cc2p: u1 = 0,
        _unused6: u1 = 0,
        ///CC2NP [7:7]
        ///Capture/Compare 2 output
        ///Polarity
        cc2np: u1 = 0,
        ///CC3E [8:8]
        ///Capture/Compare 3 output
        ///enable
        cc3e: u1 = 0,
        ///CC3P [9:9]
        ///Capture/Compare 3 output
        ///Polarity
        cc3p: u1 = 0,
        _unused10: u1 = 0,
        ///CC3NP [11:11]
        ///Capture/Compare 3 output
        ///Polarity
        cc3np: u1 = 0,
        ///CC4E [12:12]
        ///Capture/Compare 4 output
        ///enable
        cc4e: u1 = 0,
        ///CC4P [13:13]
        ///Capture/Compare 3 output
        ///Polarity
        cc4p: u1 = 0,
        _unused14: u1 = 0,
        ///CC4NP [15:15]
        ///Capture/Compare 4 output
        ///Polarity
        cc4np: u1 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40000400 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///Counter value
        cnt: u16 = 0,
        ///CNT_H [16:31]
        ///High counter value (TIM2
        ///only)
        cnt_h: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40000400 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40000400 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        ///ARR_H [16:31]
        ///High Auto-reload value (TIM2
        ///only)
        arr_h: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40000400 + 0x2C);

    //////////////////////////
    ///CCR%s
    const ccr_val = packed struct {
        ///CCR [0:15]
        ///Capture/Compare 1 value
        ccr: u16 = 0,
        ///CCR1_H [16:31]
        ///High Capture/Compare 1 value (TIM2
        ///only)
        ccr1_h: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr = Register(ccr_val).initRange(0x40000400 + 0x34, 4, 4);

    //////////////////////////
    ///DCR
    const dcr_val = packed struct {
        ///DBA [0:4]
        ///DMA base address
        dba: u5 = 0,
        _unused5: u3 = 0,
        ///DBL [8:12]
        ///DMA burst length
        dbl: u5 = 0,
        _unused13: u19 = 0,
    };
    ///DMA control register
    pub const dcr = Register(dcr_val).init(0x40000400 + 0x48);

    //////////////////////////
    ///DMAR
    const dmar_val = packed struct {
        ///DMAR [0:15]
        ///DMA register for burst
        ///accesses
        dmar: u16 = 0,
        _unused16: u16 = 0,
    };
    ///DMA address for full transfer
    pub const dmar = Register(dmar_val).init(0x40000400 + 0x4C);
};

///General-purpose-timers
pub const tim14 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        _unused3: u4 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40002000 + 0x0);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: u1 = 0,
        _unused2: u30 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40002000 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        _unused2: u7 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        _unused10: u22 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40002000 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        _unused2: u30 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40002000 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///OC1FE [2:2]
        ///Output compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output Compare 1 preload
        ///enable
        oc1pe: u1 = 0,
        ///OC1M [4:6]
        ///Output Compare 1 mode
        oc1m: u3 = 0,
        _unused7: u25 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40002000 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: u4 = 0,
        _unused8: u24 = 0,
    };
    ///capture/compare mode register (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40002000 + 0x18);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        _unused2: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        _unused4: u28 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40002000 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40002000 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40002000 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40002000 + 0x2C);

    //////////////////////////
    ///CCR%s
    const ccr_val = packed struct {
        ///CCR [0:15]
        ///Capture/Compare 1 value
        ccr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr = Register(ccr_val).initRange(0x40002000 + 0x34, 0, 1);

    //////////////////////////
    ///OR
    const _or_val = packed struct {
        ///RMP [0:1]
        ///Timer input 1 remap
        rmp: u2 = 0,
        _unused2: u30 = 0,
    };
    ///option register
    pub const _or = Register(_or_val).init(0x40002000 + 0x50);
};

///Basic-timers
pub const tim6 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Counter is not stopped at update event
            disabled = 0,
            ///Counter stops counting at the next update event (clearing the CEN bit)
            enabled = 1,
        } = .disabled,
        _unused4: u3 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        _unused8: u24 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40001000 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///MMS [4:6]
        ///Master mode selection
        mms: packed enum(u3) {
            ///Use UG bit from TIMx_EGR register
            reset = 0,
            ///Use CNT bit from TIMx_CEN register
            enable = 1,
            ///Use the update event
            update = 2,
        } = .reset,
        _unused7: u25 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40001000 + 0x4);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused1: u7 = 0,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: packed enum(u1) {
            ///Update DMA request disabled
            disabled = 0,
            ///Update DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused9: u23 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40001000 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        _unused1: u31 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40001000 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        _unused1: u31 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40001000 + 0x14);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///Low counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40001000 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40001000 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Low Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40001000 + 0x2C);
};

///Basic-timers
pub const tim7 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Counter is not stopped at update event
            disabled = 0,
            ///Counter stops counting at the next update event (clearing the CEN bit)
            enabled = 1,
        } = .disabled,
        _unused4: u3 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        _unused8: u24 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40001400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///MMS [4:6]
        ///Master mode selection
        mms: packed enum(u3) {
            ///Use UG bit from TIMx_EGR register
            reset = 0,
            ///Use CNT bit from TIMx_CEN register
            enable = 1,
            ///Use the update event
            update = 2,
        } = .reset,
        _unused7: u25 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40001400 + 0x4);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused1: u7 = 0,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: packed enum(u1) {
            ///Update DMA request disabled
            disabled = 0,
            ///Update DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused9: u23 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40001400 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        _unused1: u31 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40001400 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        _unused1: u31 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40001400 + 0x14);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///Low counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40001400 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40001400 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Low Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40001400 + 0x2C);
};

///External interrupt/event
///controller
pub const exti = struct {

    //////////////////////////
    ///IMR
    const imr_val = packed struct {
        ///MR0 [0:0]
        ///Interrupt Mask on line 0
        mr0: packed enum(u1) {
            ///Interrupt request line is masked
            masked = 0,
            ///Interrupt request line is unmasked
            unmasked = 1,
        } = .masked,
        ///MR1 [1:1]
        ///Interrupt Mask on line 1
        mr1: u1 = 0,
        ///MR2 [2:2]
        ///Interrupt Mask on line 2
        mr2: u1 = 0,
        ///MR3 [3:3]
        ///Interrupt Mask on line 3
        mr3: u1 = 0,
        ///MR4 [4:4]
        ///Interrupt Mask on line 4
        mr4: u1 = 0,
        ///MR5 [5:5]
        ///Interrupt Mask on line 5
        mr5: u1 = 0,
        ///MR6 [6:6]
        ///Interrupt Mask on line 6
        mr6: u1 = 0,
        ///MR7 [7:7]
        ///Interrupt Mask on line 7
        mr7: u1 = 0,
        ///MR8 [8:8]
        ///Interrupt Mask on line 8
        mr8: u1 = 0,
        ///MR9 [9:9]
        ///Interrupt Mask on line 9
        mr9: u1 = 0,
        ///MR10 [10:10]
        ///Interrupt Mask on line 10
        mr10: u1 = 0,
        ///MR11 [11:11]
        ///Interrupt Mask on line 11
        mr11: u1 = 0,
        ///MR12 [12:12]
        ///Interrupt Mask on line 12
        mr12: u1 = 0,
        ///MR13 [13:13]
        ///Interrupt Mask on line 13
        mr13: u1 = 0,
        ///MR14 [14:14]
        ///Interrupt Mask on line 14
        mr14: u1 = 0,
        ///MR15 [15:15]
        ///Interrupt Mask on line 15
        mr15: u1 = 0,
        ///MR16 [16:16]
        ///Interrupt Mask on line 16
        mr16: u1 = 0,
        ///MR17 [17:17]
        ///Interrupt Mask on line 17
        mr17: u1 = 0,
        ///MR18 [18:18]
        ///Interrupt Mask on line 18
        mr18: u1 = 1,
        ///MR19 [19:19]
        ///Interrupt Mask on line 19
        mr19: u1 = 0,
        ///MR20 [20:20]
        ///Interrupt Mask on line 20
        mr20: u1 = 1,
        ///MR21 [21:21]
        ///Interrupt Mask on line 21
        mr21: u1 = 0,
        ///MR22 [22:22]
        ///Interrupt Mask on line 22
        mr22: u1 = 0,
        ///MR23 [23:23]
        ///Interrupt Mask on line 23
        mr23: u1 = 1,
        ///MR24 [24:24]
        ///Interrupt Mask on line 24
        mr24: u1 = 1,
        ///MR25 [25:25]
        ///Interrupt Mask on line 25
        mr25: u1 = 1,
        ///MR26 [26:26]
        ///Interrupt Mask on line 26
        mr26: u1 = 1,
        ///MR27 [27:27]
        ///Interrupt Mask on line 27
        mr27: u1 = 1,
        _unused28: u4 = 0,
    };
    ///Interrupt mask register
    ///(EXTI_IMR)
    pub const imr = Register(imr_val).init(0x40010400 + 0x0);

    //////////////////////////
    ///EMR
    const emr_val = packed struct {
        ///MR0 [0:0]
        ///Event Mask on line 0
        mr0: packed enum(u1) {
            ///Interrupt request line is masked
            masked = 0,
            ///Interrupt request line is unmasked
            unmasked = 1,
        } = .masked,
        ///MR1 [1:1]
        ///Event Mask on line 1
        mr1: u1 = 0,
        ///MR2 [2:2]
        ///Event Mask on line 2
        mr2: u1 = 0,
        ///MR3 [3:3]
        ///Event Mask on line 3
        mr3: u1 = 0,
        ///MR4 [4:4]
        ///Event Mask on line 4
        mr4: u1 = 0,
        ///MR5 [5:5]
        ///Event Mask on line 5
        mr5: u1 = 0,
        ///MR6 [6:6]
        ///Event Mask on line 6
        mr6: u1 = 0,
        ///MR7 [7:7]
        ///Event Mask on line 7
        mr7: u1 = 0,
        ///MR8 [8:8]
        ///Event Mask on line 8
        mr8: u1 = 0,
        ///MR9 [9:9]
        ///Event Mask on line 9
        mr9: u1 = 0,
        ///MR10 [10:10]
        ///Event Mask on line 10
        mr10: u1 = 0,
        ///MR11 [11:11]
        ///Event Mask on line 11
        mr11: u1 = 0,
        ///MR12 [12:12]
        ///Event Mask on line 12
        mr12: u1 = 0,
        ///MR13 [13:13]
        ///Event Mask on line 13
        mr13: u1 = 0,
        ///MR14 [14:14]
        ///Event Mask on line 14
        mr14: u1 = 0,
        ///MR15 [15:15]
        ///Event Mask on line 15
        mr15: u1 = 0,
        ///MR16 [16:16]
        ///Event Mask on line 16
        mr16: u1 = 0,
        ///MR17 [17:17]
        ///Event Mask on line 17
        mr17: u1 = 0,
        ///MR18 [18:18]
        ///Event Mask on line 18
        mr18: u1 = 0,
        ///MR19 [19:19]
        ///Event Mask on line 19
        mr19: u1 = 0,
        ///MR20 [20:20]
        ///Event Mask on line 20
        mr20: u1 = 0,
        ///MR21 [21:21]
        ///Event Mask on line 21
        mr21: u1 = 0,
        ///MR22 [22:22]
        ///Event Mask on line 22
        mr22: u1 = 0,
        ///MR23 [23:23]
        ///Event Mask on line 23
        mr23: u1 = 0,
        ///MR24 [24:24]
        ///Event Mask on line 24
        mr24: u1 = 0,
        ///MR25 [25:25]
        ///Event Mask on line 25
        mr25: u1 = 0,
        ///MR26 [26:26]
        ///Event Mask on line 26
        mr26: u1 = 0,
        ///MR27 [27:27]
        ///Event Mask on line 27
        mr27: u1 = 0,
        _unused28: u4 = 0,
    };
    ///Event mask register (EXTI_EMR)
    pub const emr = Register(emr_val).init(0x40010400 + 0x4);

    //////////////////////////
    ///RTSR
    const rtsr_val = packed struct {
        ///TR0 [0:0]
        ///Rising trigger event configuration of
        ///line 0
        tr0: packed enum(u1) {
            ///Rising edge trigger is disabled
            disabled = 0,
            ///Rising edge trigger is enabled
            enabled = 1,
        } = .disabled,
        ///TR1 [1:1]
        ///Rising trigger event configuration of
        ///line 1
        tr1: u1 = 0,
        ///TR2 [2:2]
        ///Rising trigger event configuration of
        ///line 2
        tr2: u1 = 0,
        ///TR3 [3:3]
        ///Rising trigger event configuration of
        ///line 3
        tr3: u1 = 0,
        ///TR4 [4:4]
        ///Rising trigger event configuration of
        ///line 4
        tr4: u1 = 0,
        ///TR5 [5:5]
        ///Rising trigger event configuration of
        ///line 5
        tr5: u1 = 0,
        ///TR6 [6:6]
        ///Rising trigger event configuration of
        ///line 6
        tr6: u1 = 0,
        ///TR7 [7:7]
        ///Rising trigger event configuration of
        ///line 7
        tr7: u1 = 0,
        ///TR8 [8:8]
        ///Rising trigger event configuration of
        ///line 8
        tr8: u1 = 0,
        ///TR9 [9:9]
        ///Rising trigger event configuration of
        ///line 9
        tr9: u1 = 0,
        ///TR10 [10:10]
        ///Rising trigger event configuration of
        ///line 10
        tr10: u1 = 0,
        ///TR11 [11:11]
        ///Rising trigger event configuration of
        ///line 11
        tr11: u1 = 0,
        ///TR12 [12:12]
        ///Rising trigger event configuration of
        ///line 12
        tr12: u1 = 0,
        ///TR13 [13:13]
        ///Rising trigger event configuration of
        ///line 13
        tr13: u1 = 0,
        ///TR14 [14:14]
        ///Rising trigger event configuration of
        ///line 14
        tr14: u1 = 0,
        ///TR15 [15:15]
        ///Rising trigger event configuration of
        ///line 15
        tr15: u1 = 0,
        ///TR16 [16:16]
        ///Rising trigger event configuration of
        ///line 16
        tr16: u1 = 0,
        ///TR17 [17:17]
        ///Rising trigger event configuration of
        ///line 17
        tr17: u1 = 0,
        _unused18: u1 = 0,
        ///TR19 [19:19]
        ///Rising trigger event configuration of
        ///line 19
        tr19: u1 = 0,
        _unused20: u12 = 0,
    };
    ///Rising Trigger selection register
    ///(EXTI_RTSR)
    pub const rtsr = Register(rtsr_val).init(0x40010400 + 0x8);

    //////////////////////////
    ///FTSR
    const ftsr_val = packed struct {
        ///TR0 [0:0]
        ///Falling trigger event configuration of
        ///line 0
        tr0: packed enum(u1) {
            ///Falling edge trigger is disabled
            disabled = 0,
            ///Falling edge trigger is enabled
            enabled = 1,
        } = .disabled,
        ///TR1 [1:1]
        ///Falling trigger event configuration of
        ///line 1
        tr1: u1 = 0,
        ///TR2 [2:2]
        ///Falling trigger event configuration of
        ///line 2
        tr2: u1 = 0,
        ///TR3 [3:3]
        ///Falling trigger event configuration of
        ///line 3
        tr3: u1 = 0,
        ///TR4 [4:4]
        ///Falling trigger event configuration of
        ///line 4
        tr4: u1 = 0,
        ///TR5 [5:5]
        ///Falling trigger event configuration of
        ///line 5
        tr5: u1 = 0,
        ///TR6 [6:6]
        ///Falling trigger event configuration of
        ///line 6
        tr6: u1 = 0,
        ///TR7 [7:7]
        ///Falling trigger event configuration of
        ///line 7
        tr7: u1 = 0,
        ///TR8 [8:8]
        ///Falling trigger event configuration of
        ///line 8
        tr8: u1 = 0,
        ///TR9 [9:9]
        ///Falling trigger event configuration of
        ///line 9
        tr9: u1 = 0,
        ///TR10 [10:10]
        ///Falling trigger event configuration of
        ///line 10
        tr10: u1 = 0,
        ///TR11 [11:11]
        ///Falling trigger event configuration of
        ///line 11
        tr11: u1 = 0,
        ///TR12 [12:12]
        ///Falling trigger event configuration of
        ///line 12
        tr12: u1 = 0,
        ///TR13 [13:13]
        ///Falling trigger event configuration of
        ///line 13
        tr13: u1 = 0,
        ///TR14 [14:14]
        ///Falling trigger event configuration of
        ///line 14
        tr14: u1 = 0,
        ///TR15 [15:15]
        ///Falling trigger event configuration of
        ///line 15
        tr15: u1 = 0,
        ///TR16 [16:16]
        ///Falling trigger event configuration of
        ///line 16
        tr16: u1 = 0,
        ///TR17 [17:17]
        ///Falling trigger event configuration of
        ///line 17
        tr17: u1 = 0,
        _unused18: u1 = 0,
        ///TR19 [19:19]
        ///Falling trigger event configuration of
        ///line 19
        tr19: u1 = 0,
        _unused20: u12 = 0,
    };
    ///Falling Trigger selection register
    ///(EXTI_FTSR)
    pub const ftsr = Register(ftsr_val).init(0x40010400 + 0xC);

    //////////////////////////
    ///SWIER
    const swier_val = packed struct {
        ///SWIER0 [0:0]
        ///Software Interrupt on line
        ///0
        swier0: u1 = 0,
        ///SWIER1 [1:1]
        ///Software Interrupt on line
        ///1
        swier1: u1 = 0,
        ///SWIER2 [2:2]
        ///Software Interrupt on line
        ///2
        swier2: u1 = 0,
        ///SWIER3 [3:3]
        ///Software Interrupt on line
        ///3
        swier3: u1 = 0,
        ///SWIER4 [4:4]
        ///Software Interrupt on line
        ///4
        swier4: u1 = 0,
        ///SWIER5 [5:5]
        ///Software Interrupt on line
        ///5
        swier5: u1 = 0,
        ///SWIER6 [6:6]
        ///Software Interrupt on line
        ///6
        swier6: u1 = 0,
        ///SWIER7 [7:7]
        ///Software Interrupt on line
        ///7
        swier7: u1 = 0,
        ///SWIER8 [8:8]
        ///Software Interrupt on line
        ///8
        swier8: u1 = 0,
        ///SWIER9 [9:9]
        ///Software Interrupt on line
        ///9
        swier9: u1 = 0,
        ///SWIER10 [10:10]
        ///Software Interrupt on line
        ///10
        swier10: u1 = 0,
        ///SWIER11 [11:11]
        ///Software Interrupt on line
        ///11
        swier11: u1 = 0,
        ///SWIER12 [12:12]
        ///Software Interrupt on line
        ///12
        swier12: u1 = 0,
        ///SWIER13 [13:13]
        ///Software Interrupt on line
        ///13
        swier13: u1 = 0,
        ///SWIER14 [14:14]
        ///Software Interrupt on line
        ///14
        swier14: u1 = 0,
        ///SWIER15 [15:15]
        ///Software Interrupt on line
        ///15
        swier15: u1 = 0,
        ///SWIER16 [16:16]
        ///Software Interrupt on line
        ///16
        swier16: u1 = 0,
        ///SWIER17 [17:17]
        ///Software Interrupt on line
        ///17
        swier17: u1 = 0,
        _unused18: u1 = 0,
        ///SWIER19 [19:19]
        ///Software Interrupt on line
        ///19
        swier19: u1 = 0,
        _unused20: u12 = 0,
    };
    ///Software interrupt event register
    ///(EXTI_SWIER)
    pub const swier = Register(swier_val).init(0x40010400 + 0x10);

    //////////////////////////
    ///PR
    const pr_val_read = packed struct {
        ///PR0 [0:0]
        ///Pending bit 0
        pr0: packed enum(u1) {
            ///No trigger request occurred
            not_pending = 0,
            ///Selected trigger request occurred
            pending = 1,
        } = .not_pending,
        ///PR1 [1:1]
        ///Pending bit 1
        pr1: u1 = 0,
        ///PR2 [2:2]
        ///Pending bit 2
        pr2: u1 = 0,
        ///PR3 [3:3]
        ///Pending bit 3
        pr3: u1 = 0,
        ///PR4 [4:4]
        ///Pending bit 4
        pr4: u1 = 0,
        ///PR5 [5:5]
        ///Pending bit 5
        pr5: u1 = 0,
        ///PR6 [6:6]
        ///Pending bit 6
        pr6: u1 = 0,
        ///PR7 [7:7]
        ///Pending bit 7
        pr7: u1 = 0,
        ///PR8 [8:8]
        ///Pending bit 8
        pr8: u1 = 0,
        ///PR9 [9:9]
        ///Pending bit 9
        pr9: u1 = 0,
        ///PR10 [10:10]
        ///Pending bit 10
        pr10: u1 = 0,
        ///PR11 [11:11]
        ///Pending bit 11
        pr11: u1 = 0,
        ///PR12 [12:12]
        ///Pending bit 12
        pr12: u1 = 0,
        ///PR13 [13:13]
        ///Pending bit 13
        pr13: u1 = 0,
        ///PR14 [14:14]
        ///Pending bit 14
        pr14: u1 = 0,
        ///PR15 [15:15]
        ///Pending bit 15
        pr15: u1 = 0,
        ///PR16 [16:16]
        ///Pending bit 16
        pr16: u1 = 0,
        ///PR17 [17:17]
        ///Pending bit 17
        pr17: u1 = 0,
        _unused18: u1 = 0,
        ///PR19 [19:19]
        ///Pending bit 19
        pr19: u1 = 0,
        _unused20: u12 = 0,
    };
    const pr_val_write = packed struct {
        ///PR0 [0:0]
        ///Pending bit 0
        pr0: packed enum(u1) {
            ///Clears pending bit
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///PR1 [1:1]
        ///Pending bit 1
        pr1: u1 = 0,
        ///PR2 [2:2]
        ///Pending bit 2
        pr2: u1 = 0,
        ///PR3 [3:3]
        ///Pending bit 3
        pr3: u1 = 0,
        ///PR4 [4:4]
        ///Pending bit 4
        pr4: u1 = 0,
        ///PR5 [5:5]
        ///Pending bit 5
        pr5: u1 = 0,
        ///PR6 [6:6]
        ///Pending bit 6
        pr6: u1 = 0,
        ///PR7 [7:7]
        ///Pending bit 7
        pr7: u1 = 0,
        ///PR8 [8:8]
        ///Pending bit 8
        pr8: u1 = 0,
        ///PR9 [9:9]
        ///Pending bit 9
        pr9: u1 = 0,
        ///PR10 [10:10]
        ///Pending bit 10
        pr10: u1 = 0,
        ///PR11 [11:11]
        ///Pending bit 11
        pr11: u1 = 0,
        ///PR12 [12:12]
        ///Pending bit 12
        pr12: u1 = 0,
        ///PR13 [13:13]
        ///Pending bit 13
        pr13: u1 = 0,
        ///PR14 [14:14]
        ///Pending bit 14
        pr14: u1 = 0,
        ///PR15 [15:15]
        ///Pending bit 15
        pr15: u1 = 0,
        ///PR16 [16:16]
        ///Pending bit 16
        pr16: u1 = 0,
        ///PR17 [17:17]
        ///Pending bit 17
        pr17: u1 = 0,
        _unused18: u1 = 0,
        ///PR19 [19:19]
        ///Pending bit 19
        pr19: u1 = 0,
        _unused20: u12 = 0,
    };
    ///Pending register (EXTI_PR)
    pub const pr = RegisterRW(pr_val_read, pr_val_write).init(0x40010400 + 0x14);
};

///Nested Vectored Interrupt
///Controller
pub const nvic = struct {

    //////////////////////////
    ///ISER
    const iser_val = packed struct {
        ///SETENA [0:31]
        ///SETENA
        setena: u32 = 0,
    };
    ///Interrupt Set Enable Register
    pub const iser = Register(iser_val).init(0xE000E100 + 0x0);

    //////////////////////////
    ///ICER
    const icer_val = packed struct {
        ///CLRENA [0:31]
        ///CLRENA
        clrena: u32 = 0,
    };
    ///Interrupt Clear Enable
    ///Register
    pub const icer = Register(icer_val).init(0xE000E100 + 0x80);

    //////////////////////////
    ///ISPR
    const ispr_val = packed struct {
        ///SETPEND [0:31]
        ///SETPEND
        setpend: u32 = 0,
    };
    ///Interrupt Set-Pending Register
    pub const ispr = Register(ispr_val).init(0xE000E100 + 0x100);

    //////////////////////////
    ///ICPR
    const icpr_val = packed struct {
        ///CLRPEND [0:31]
        ///CLRPEND
        clrpend: u32 = 0,
    };
    ///Interrupt Clear-Pending
    ///Register
    pub const icpr = Register(icpr_val).init(0xE000E100 + 0x180);

    //////////////////////////
    ///IPR0
    const ipr0_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_00 [6:7]
        ///PRI_00
        pri_00: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_01 [14:15]
        ///PRI_01
        pri_01: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_02 [22:23]
        ///PRI_02
        pri_02: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_03 [30:31]
        ///PRI_03
        pri_03: u2 = 0,
    };
    ///Interrupt Priority Register 0
    pub const ipr0 = Register(ipr0_val).init(0xE000E100 + 0x300);

    //////////////////////////
    ///IPR1
    const ipr1_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_40 [6:7]
        ///PRI_40
        pri_40: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_41 [14:15]
        ///PRI_41
        pri_41: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_42 [22:23]
        ///PRI_42
        pri_42: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_43 [30:31]
        ///PRI_43
        pri_43: u2 = 0,
    };
    ///Interrupt Priority Register 1
    pub const ipr1 = Register(ipr1_val).init(0xE000E100 + 0x304);

    //////////////////////////
    ///IPR2
    const ipr2_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_80 [6:7]
        ///PRI_80
        pri_80: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_81 [14:15]
        ///PRI_81
        pri_81: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_82 [22:23]
        ///PRI_82
        pri_82: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_83 [30:31]
        ///PRI_83
        pri_83: u2 = 0,
    };
    ///Interrupt Priority Register 2
    pub const ipr2 = Register(ipr2_val).init(0xE000E100 + 0x308);

    //////////////////////////
    ///IPR3
    const ipr3_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_120 [6:7]
        ///PRI_120
        pri_120: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_121 [14:15]
        ///PRI_121
        pri_121: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_122 [22:23]
        ///PRI_122
        pri_122: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_123 [30:31]
        ///PRI_123
        pri_123: u2 = 0,
    };
    ///Interrupt Priority Register 3
    pub const ipr3 = Register(ipr3_val).init(0xE000E100 + 0x30C);

    //////////////////////////
    ///IPR4
    const ipr4_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_160 [6:7]
        ///PRI_160
        pri_160: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_161 [14:15]
        ///PRI_161
        pri_161: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_162 [22:23]
        ///PRI_162
        pri_162: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_163 [30:31]
        ///PRI_163
        pri_163: u2 = 0,
    };
    ///Interrupt Priority Register 4
    pub const ipr4 = Register(ipr4_val).init(0xE000E100 + 0x310);

    //////////////////////////
    ///IPR5
    const ipr5_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_200 [6:7]
        ///PRI_200
        pri_200: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_201 [14:15]
        ///PRI_201
        pri_201: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_202 [22:23]
        ///PRI_202
        pri_202: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_203 [30:31]
        ///PRI_203
        pri_203: u2 = 0,
    };
    ///Interrupt Priority Register 5
    pub const ipr5 = Register(ipr5_val).init(0xE000E100 + 0x314);

    //////////////////////////
    ///IPR6
    const ipr6_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_240 [6:7]
        ///PRI_240
        pri_240: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_241 [14:15]
        ///PRI_241
        pri_241: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_242 [22:23]
        ///PRI_242
        pri_242: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_243 [30:31]
        ///PRI_243
        pri_243: u2 = 0,
    };
    ///Interrupt Priority Register 6
    pub const ipr6 = Register(ipr6_val).init(0xE000E100 + 0x318);

    //////////////////////////
    ///IPR7
    const ipr7_val = packed struct {
        _unused0: u6 = 0,
        ///PRI_280 [6:7]
        ///PRI_280
        pri_280: u2 = 0,
        _unused8: u6 = 0,
        ///PRI_281 [14:15]
        ///PRI_281
        pri_281: u2 = 0,
        _unused16: u6 = 0,
        ///PRI_282 [22:23]
        ///PRI_282
        pri_282: u2 = 0,
        _unused24: u6 = 0,
        ///PRI_283 [30:31]
        ///PRI_283
        pri_283: u2 = 0,
    };
    ///Interrupt Priority Register 7
    pub const ipr7 = Register(ipr7_val).init(0xE000E100 + 0x31C);
};

///DMA controller
pub const dma1 = struct {

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///GIF1 [0:0]
        ///Channel 1 Global interrupt
        ///flag
        gif1: packed enum(u1) {
            ///No transfer error, half event, complete event
            no_event = 0,
            ///A transfer error, half event or complete event has occured
            event = 1,
        } = .no_event,
        ///TCIF1 [1:1]
        ///Channel 1 Transfer Complete
        ///flag
        tcif1: packed enum(u1) {
            ///No transfer complete event
            not_complete = 0,
            ///A transfer complete event has occured
            complete = 1,
        } = .not_complete,
        ///HTIF1 [2:2]
        ///Channel 1 Half Transfer Complete
        ///flag
        htif1: packed enum(u1) {
            ///No half transfer event
            not_half = 0,
            ///A half transfer event has occured
            half = 1,
        } = .not_half,
        ///TEIF1 [3:3]
        ///Channel 1 Transfer Error
        ///flag
        teif1: packed enum(u1) {
            ///No transfer error
            no_error = 0,
            ///A transfer error has occured
            _error = 1,
        } = .no_error,
        ///GIF2 [4:4]
        ///Channel 2 Global interrupt
        ///flag
        gif2: u1 = 0,
        ///TCIF2 [5:5]
        ///Channel 2 Transfer Complete
        ///flag
        tcif2: u1 = 0,
        ///HTIF2 [6:6]
        ///Channel 2 Half Transfer Complete
        ///flag
        htif2: u1 = 0,
        ///TEIF2 [7:7]
        ///Channel 2 Transfer Error
        ///flag
        teif2: u1 = 0,
        ///GIF3 [8:8]
        ///Channel 3 Global interrupt
        ///flag
        gif3: u1 = 0,
        ///TCIF3 [9:9]
        ///Channel 3 Transfer Complete
        ///flag
        tcif3: u1 = 0,
        ///HTIF3 [10:10]
        ///Channel 3 Half Transfer Complete
        ///flag
        htif3: u1 = 0,
        ///TEIF3 [11:11]
        ///Channel 3 Transfer Error
        ///flag
        teif3: u1 = 0,
        ///GIF4 [12:12]
        ///Channel 4 Global interrupt
        ///flag
        gif4: u1 = 0,
        ///TCIF4 [13:13]
        ///Channel 4 Transfer Complete
        ///flag
        tcif4: u1 = 0,
        ///HTIF4 [14:14]
        ///Channel 4 Half Transfer Complete
        ///flag
        htif4: u1 = 0,
        ///TEIF4 [15:15]
        ///Channel 4 Transfer Error
        ///flag
        teif4: u1 = 0,
        ///GIF5 [16:16]
        ///Channel 5 Global interrupt
        ///flag
        gif5: u1 = 0,
        ///TCIF5 [17:17]
        ///Channel 5 Transfer Complete
        ///flag
        tcif5: u1 = 0,
        ///HTIF5 [18:18]
        ///Channel 5 Half Transfer Complete
        ///flag
        htif5: u1 = 0,
        ///TEIF5 [19:19]
        ///Channel 5 Transfer Error
        ///flag
        teif5: u1 = 0,
        ///GIF6 [20:20]
        ///Channel 6 Global interrupt
        ///flag
        gif6: u1 = 0,
        ///TCIF6 [21:21]
        ///Channel 6 Transfer Complete
        ///flag
        tcif6: u1 = 0,
        ///HTIF6 [22:22]
        ///Channel 6 Half Transfer Complete
        ///flag
        htif6: u1 = 0,
        ///TEIF6 [23:23]
        ///Channel 6 Transfer Error
        ///flag
        teif6: u1 = 0,
        ///GIF7 [24:24]
        ///Channel 7 Global interrupt
        ///flag
        gif7: u1 = 0,
        ///TCIF7 [25:25]
        ///Channel 7 Transfer Complete
        ///flag
        tcif7: u1 = 0,
        ///HTIF7 [26:26]
        ///Channel 7 Half Transfer Complete
        ///flag
        htif7: u1 = 0,
        ///TEIF7 [27:27]
        ///Channel 7 Transfer Error
        ///flag
        teif7: u1 = 0,
        _unused28: u4 = 0,
    };
    ///DMA interrupt status register
    ///(DMA_ISR)
    pub const isr = RegisterRW(isr_val, void).init(0x40020000 + 0x0);

    //////////////////////////
    ///IFCR
    const ifcr_val = packed struct {
        ///CGIF1 [0:0]
        ///Channel 1 Global interrupt
        ///clear
        cgif1: packed enum(u1) {
            ///Clears the GIF, TEIF, HTIF, TCIF flags in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTCIF1 [1:1]
        ///Channel 1 Transfer Complete
        ///clear
        ctcif1: packed enum(u1) {
            ///Clears the TCIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CHTIF1 [2:2]
        ///Channel 1 Half Transfer
        ///clear
        chtif1: packed enum(u1) {
            ///Clears the HTIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTEIF1 [3:3]
        ///Channel 1 Transfer Error
        ///clear
        cteif1: packed enum(u1) {
            ///Clears the TEIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CGIF2 [4:4]
        ///Channel 2 Global interrupt
        ///clear
        cgif2: u1 = 0,
        ///CTCIF2 [5:5]
        ///Channel 2 Transfer Complete
        ///clear
        ctcif2: u1 = 0,
        ///CHTIF2 [6:6]
        ///Channel 2 Half Transfer
        ///clear
        chtif2: u1 = 0,
        ///CTEIF2 [7:7]
        ///Channel 2 Transfer Error
        ///clear
        cteif2: u1 = 0,
        ///CGIF3 [8:8]
        ///Channel 3 Global interrupt
        ///clear
        cgif3: u1 = 0,
        ///CTCIF3 [9:9]
        ///Channel 3 Transfer Complete
        ///clear
        ctcif3: u1 = 0,
        ///CHTIF3 [10:10]
        ///Channel 3 Half Transfer
        ///clear
        chtif3: u1 = 0,
        ///CTEIF3 [11:11]
        ///Channel 3 Transfer Error
        ///clear
        cteif3: u1 = 0,
        ///CGIF4 [12:12]
        ///Channel 4 Global interrupt
        ///clear
        cgif4: u1 = 0,
        ///CTCIF4 [13:13]
        ///Channel 4 Transfer Complete
        ///clear
        ctcif4: u1 = 0,
        ///CHTIF4 [14:14]
        ///Channel 4 Half Transfer
        ///clear
        chtif4: u1 = 0,
        ///CTEIF4 [15:15]
        ///Channel 4 Transfer Error
        ///clear
        cteif4: u1 = 0,
        ///CGIF5 [16:16]
        ///Channel 5 Global interrupt
        ///clear
        cgif5: u1 = 0,
        ///CTCIF5 [17:17]
        ///Channel 5 Transfer Complete
        ///clear
        ctcif5: u1 = 0,
        ///CHTIF5 [18:18]
        ///Channel 5 Half Transfer
        ///clear
        chtif5: u1 = 0,
        ///CTEIF5 [19:19]
        ///Channel 5 Transfer Error
        ///clear
        cteif5: u1 = 0,
        ///CGIF6 [20:20]
        ///Channel 6 Global interrupt
        ///clear
        cgif6: u1 = 0,
        ///CTCIF6 [21:21]
        ///Channel 6 Transfer Complete
        ///clear
        ctcif6: u1 = 0,
        ///CHTIF6 [22:22]
        ///Channel 6 Half Transfer
        ///clear
        chtif6: u1 = 0,
        ///CTEIF6 [23:23]
        ///Channel 6 Transfer Error
        ///clear
        cteif6: u1 = 0,
        ///CGIF7 [24:24]
        ///Channel 7 Global interrupt
        ///clear
        cgif7: u1 = 0,
        ///CTCIF7 [25:25]
        ///Channel 7 Transfer Complete
        ///clear
        ctcif7: u1 = 0,
        ///CHTIF7 [26:26]
        ///Channel 7 Half Transfer
        ///clear
        chtif7: u1 = 0,
        ///CTEIF7 [27:27]
        ///Channel 7 Transfer Error
        ///clear
        cteif7: u1 = 0,
        _unused28: u4 = 0,
    };
    ///DMA interrupt flag clear register
    ///(DMA_IFCR)
    pub const ifcr = RegisterRW(void, ifcr_val).init(0x40020000 + 0x4);
};

///Reset and clock control
pub const rcc = struct {

    //////////////////////////
    ///CR
    const cr_val_read = packed struct {
        ///HSION [0:0]
        ///Internal High Speed clock
        ///enable
        hsion: u1 = 1,
        ///HSIRDY [1:1]
        ///Internal High Speed clock ready
        ///flag
        hsirdy: packed enum(u1) {
            ///Clock not ready
            not_ready = 0,
            ///Clock ready
            ready = 1,
        } = .ready,
        _unused2: u1 = 0,
        ///HSITRIM [3:7]
        ///Internal High Speed clock
        ///trimming
        hsitrim: u5 = 16,
        ///HSICAL [8:15]
        ///Internal High Speed clock
        ///Calibration
        hsical: u8 = 0,
        ///HSEON [16:16]
        ///External High Speed clock
        ///enable
        hseon: u1 = 0,
        ///HSERDY [17:17]
        ///External High Speed clock ready
        ///flag
        hserdy: u1 = 0,
        ///HSEBYP [18:18]
        ///External High Speed clock
        ///Bypass
        hsebyp: u1 = 0,
        ///CSSON [19:19]
        ///Clock Security System
        ///enable
        csson: u1 = 0,
        _unused20: u4 = 0,
        ///PLLON [24:24]
        ///PLL enable
        pllon: u1 = 0,
        ///PLLRDY [25:25]
        ///PLL clock ready flag
        pllrdy: u1 = 0,
        _unused26: u6 = 0,
    };
    const cr_val_write = packed struct {
        ///HSION [0:0]
        ///Internal High Speed clock
        ///enable
        hsion: u1 = 1,
        ///HSIRDY [1:1]
        ///Internal High Speed clock ready
        ///flag
        hsirdy: u1 = 1,
        _unused2: u1 = 0,
        ///HSITRIM [3:7]
        ///Internal High Speed clock
        ///trimming
        hsitrim: u5 = 16,
        ///HSICAL [8:15]
        ///Internal High Speed clock
        ///Calibration
        hsical: u8 = 0,
        ///HSEON [16:16]
        ///External High Speed clock
        ///enable
        hseon: u1 = 0,
        ///HSERDY [17:17]
        ///External High Speed clock ready
        ///flag
        hserdy: u1 = 0,
        ///HSEBYP [18:18]
        ///External High Speed clock
        ///Bypass
        hsebyp: u1 = 0,
        ///CSSON [19:19]
        ///Clock Security System
        ///enable
        csson: u1 = 0,
        _unused20: u4 = 0,
        ///PLLON [24:24]
        ///PLL enable
        pllon: u1 = 0,
        ///PLLRDY [25:25]
        ///PLL clock ready flag
        pllrdy: u1 = 0,
        _unused26: u6 = 0,
    };
    ///Clock control register
    pub const cr = Register(cr_val).init(0x40021000 + 0x0);

    //////////////////////////
    ///CFGR
    const cfgr_val_read = packed struct {
        ///SW [0:1]
        ///System clock Switch
        sw: u2 = 0,
        ///SWS [2:3]
        ///System Clock Switch Status
        sws: packed enum(u2) {
            ///HSI48 used as system clock (when avaiable)
            hsi48 = 3,
            ///HSI oscillator used as system clock
            hsi = 0,
            ///HSE oscillator used as system clock
            hse = 1,
            ///PLL used as system clock
            pll = 2,
        } = .hsi,
        ///HPRE [4:7]
        ///AHB prescaler
        hpre: u4 = 0,
        ///PPRE [8:10]
        ///APB Low speed prescaler
        ///(APB1)
        ppre: u3 = 0,
        _unused11: u3 = 0,
        ///ADCPRE [14:14]
        ///APCPRE is deprecated. See ADC field in CFGR2 register.
        adcpre: u1 = 0,
        _unused15: u1 = 0,
        ///PLLSRC [16:16]
        ///PLL input clock source
        pllsrc: u1 = 0,
        ///PLLXTPRE [17:17]
        ///HSE divider for PLL entry. Same bit as PREDIC[0] from CFGR2 register. Refer to it for its meaning
        pllxtpre: u1 = 0,
        ///PLLMUL [18:21]
        ///PLL Multiplication Factor
        pllmul: u4 = 0,
        _unused22: u2 = 0,
        ///MCO [24:26]
        ///Microcontroller clock
        ///output
        mco: u3 = 0,
        _unused27: u1 = 0,
        ///MCOPRE [28:30]
        ///Microcontroller Clock Output
        ///Prescaler
        mcopre: u3 = 0,
        ///PLLNODIV [31:31]
        ///PLL clock not divided for
        ///MCO
        pllnodiv: u1 = 0,
    };
    const cfgr_val_write = packed struct {
        ///SW [0:1]
        ///System clock Switch
        sw: u2 = 0,
        ///SWS [2:3]
        ///System Clock Switch Status
        sws: u2 = 0,
        ///HPRE [4:7]
        ///AHB prescaler
        hpre: u4 = 0,
        ///PPRE [8:10]
        ///APB Low speed prescaler
        ///(APB1)
        ppre: u3 = 0,
        _unused11: u3 = 0,
        ///ADCPRE [14:14]
        ///APCPRE is deprecated. See ADC field in CFGR2 register.
        adcpre: u1 = 0,
        _unused15: u1 = 0,
        ///PLLSRC [16:16]
        ///PLL input clock source
        pllsrc: u1 = 0,
        ///PLLXTPRE [17:17]
        ///HSE divider for PLL entry. Same bit as PREDIC[0] from CFGR2 register. Refer to it for its meaning
        pllxtpre: u1 = 0,
        ///PLLMUL [18:21]
        ///PLL Multiplication Factor
        pllmul: u4 = 0,
        _unused22: u2 = 0,
        ///MCO [24:26]
        ///Microcontroller clock
        ///output
        mco: u3 = 0,
        _unused27: u1 = 0,
        ///MCOPRE [28:30]
        ///Microcontroller Clock Output
        ///Prescaler
        mcopre: u3 = 0,
        ///PLLNODIV [31:31]
        ///PLL clock not divided for
        ///MCO
        pllnodiv: u1 = 0,
    };
    ///Clock configuration register
    ///(RCC_CFGR)
    pub const cfgr = Register(cfgr_val).init(0x40021000 + 0x4);

    //////////////////////////
    ///CIR
    const cir_val_read = packed struct {
        ///LSIRDYF [0:0]
        ///LSI Ready Interrupt flag
        lsirdyf: packed enum(u1) {
            ///No clock ready interrupt
            not_interrupted = 0,
            ///Clock ready interrupt
            interrupted = 1,
        } = .not_interrupted,
        ///LSERDYF [1:1]
        ///LSE Ready Interrupt flag
        lserdyf: u1 = 0,
        ///HSIRDYF [2:2]
        ///HSI Ready Interrupt flag
        hsirdyf: u1 = 0,
        ///HSERDYF [3:3]
        ///HSE Ready Interrupt flag
        hserdyf: u1 = 0,
        ///PLLRDYF [4:4]
        ///PLL Ready Interrupt flag
        pllrdyf: u1 = 0,
        ///HSI14RDYF [5:5]
        ///HSI14 ready interrupt flag
        hsi14rdyf: u1 = 0,
        ///HSI48RDYF [6:6]
        ///HSI48 ready interrupt flag
        hsi48rdyf: u1 = 0,
        ///CSSF [7:7]
        ///Clock Security System Interrupt
        ///flag
        cssf: packed enum(u1) {
            ///No clock security interrupt caused by HSE clock failure
            not_interrupted = 0,
            ///Clock security interrupt caused by HSE clock failure
            interrupted = 1,
        } = .not_interrupted,
        ///LSIRDYIE [8:8]
        ///LSI Ready Interrupt Enable
        lsirdyie: u1 = 0,
        ///LSERDYIE [9:9]
        ///LSE Ready Interrupt Enable
        lserdyie: u1 = 0,
        ///HSIRDYIE [10:10]
        ///HSI Ready Interrupt Enable
        hsirdyie: u1 = 0,
        ///HSERDYIE [11:11]
        ///HSE Ready Interrupt Enable
        hserdyie: u1 = 0,
        ///PLLRDYIE [12:12]
        ///PLL Ready Interrupt Enable
        pllrdyie: u1 = 0,
        ///HSI14RDYIE [13:13]
        ///HSI14 ready interrupt
        ///enable
        hsi14rdyie: u1 = 0,
        ///HSI48RDYIE [14:14]
        ///HSI48 ready interrupt
        ///enable
        hsi48rdyie: u1 = 0,
        _unused15: u1 = 0,
        ///LSIRDYC [16:16]
        ///LSI Ready Interrupt Clear
        lsirdyc: u1 = 0,
        ///LSERDYC [17:17]
        ///LSE Ready Interrupt Clear
        lserdyc: u1 = 0,
        ///HSIRDYC [18:18]
        ///HSI Ready Interrupt Clear
        hsirdyc: u1 = 0,
        ///HSERDYC [19:19]
        ///HSE Ready Interrupt Clear
        hserdyc: u1 = 0,
        ///PLLRDYC [20:20]
        ///PLL Ready Interrupt Clear
        pllrdyc: u1 = 0,
        ///HSI14RDYC [21:21]
        ///HSI 14 MHz Ready Interrupt
        ///Clear
        hsi14rdyc: u1 = 0,
        ///HSI48RDYC [22:22]
        ///HSI48 Ready Interrupt
        ///Clear
        hsi48rdyc: u1 = 0,
        ///CSSC [23:23]
        ///Clock security system interrupt
        ///clear
        cssc: u1 = 0,
        _unused24: u8 = 0,
    };
    const cir_val_write = packed struct {
        ///LSIRDYF [0:0]
        ///LSI Ready Interrupt flag
        lsirdyf: u1 = 0,
        ///LSERDYF [1:1]
        ///LSE Ready Interrupt flag
        lserdyf: u1 = 0,
        ///HSIRDYF [2:2]
        ///HSI Ready Interrupt flag
        hsirdyf: u1 = 0,
        ///HSERDYF [3:3]
        ///HSE Ready Interrupt flag
        hserdyf: u1 = 0,
        ///PLLRDYF [4:4]
        ///PLL Ready Interrupt flag
        pllrdyf: u1 = 0,
        ///HSI14RDYF [5:5]
        ///HSI14 ready interrupt flag
        hsi14rdyf: u1 = 0,
        ///HSI48RDYF [6:6]
        ///HSI48 ready interrupt flag
        hsi48rdyf: u1 = 0,
        ///CSSF [7:7]
        ///Clock Security System Interrupt
        ///flag
        cssf: u1 = 0,
        ///LSIRDYIE [8:8]
        ///LSI Ready Interrupt Enable
        lsirdyie: u1 = 0,
        ///LSERDYIE [9:9]
        ///LSE Ready Interrupt Enable
        lserdyie: u1 = 0,
        ///HSIRDYIE [10:10]
        ///HSI Ready Interrupt Enable
        hsirdyie: u1 = 0,
        ///HSERDYIE [11:11]
        ///HSE Ready Interrupt Enable
        hserdyie: u1 = 0,
        ///PLLRDYIE [12:12]
        ///PLL Ready Interrupt Enable
        pllrdyie: u1 = 0,
        ///HSI14RDYIE [13:13]
        ///HSI14 ready interrupt
        ///enable
        hsi14rdyie: u1 = 0,
        ///HSI48RDYIE [14:14]
        ///HSI48 ready interrupt
        ///enable
        hsi48rdyie: u1 = 0,
        _unused15: u1 = 0,
        ///LSIRDYC [16:16]
        ///LSI Ready Interrupt Clear
        lsirdyc: packed enum(u1) {
            ///Clear interrupt flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///LSERDYC [17:17]
        ///LSE Ready Interrupt Clear
        lserdyc: u1 = 0,
        ///HSIRDYC [18:18]
        ///HSI Ready Interrupt Clear
        hsirdyc: u1 = 0,
        ///HSERDYC [19:19]
        ///HSE Ready Interrupt Clear
        hserdyc: u1 = 0,
        ///PLLRDYC [20:20]
        ///PLL Ready Interrupt Clear
        pllrdyc: u1 = 0,
        ///HSI14RDYC [21:21]
        ///HSI 14 MHz Ready Interrupt
        ///Clear
        hsi14rdyc: u1 = 0,
        ///HSI48RDYC [22:22]
        ///HSI48 Ready Interrupt
        ///Clear
        hsi48rdyc: u1 = 0,
        ///CSSC [23:23]
        ///Clock security system interrupt
        ///clear
        cssc: packed enum(u1) {
            ///Clear CSSF flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused24: u8 = 0,
    };
    ///Clock interrupt register
    ///(RCC_CIR)
    pub const cir = Register(cir_val).init(0x40021000 + 0x8);

    //////////////////////////
    ///APB2RSTR
    const apb2rstr_val = packed struct {
        ///SYSCFGRST [0:0]
        ///SYSCFG and COMP reset
        syscfgrst: packed enum(u1) {
            ///Reset the selected module
            reset = 1,
            _zero = 0,
        } = ._zero,
        _unused1: u4 = 0,
        ///USART6RST [5:5]
        ///USART6 reset
        usart6rst: u1 = 0,
        _unused6: u3 = 0,
        ///ADCRST [9:9]
        ///ADC interface reset
        adcrst: u1 = 0,
        _unused10: u1 = 0,
        ///TIM1RST [11:11]
        ///TIM1 timer reset
        tim1rst: u1 = 0,
        ///SPI1RST [12:12]
        ///SPI 1 reset
        spi1rst: u1 = 0,
        _unused13: u1 = 0,
        ///USART1RST [14:14]
        ///USART1 reset
        usart1rst: u1 = 0,
        _unused15: u1 = 0,
        ///TIM15RST [16:16]
        ///TIM15 timer reset
        tim15rst: u1 = 0,
        ///TIM16RST [17:17]
        ///TIM16 timer reset
        tim16rst: u1 = 0,
        ///TIM17RST [18:18]
        ///TIM17 timer reset
        tim17rst: u1 = 0,
        _unused19: u3 = 0,
        ///DBGMCURST [22:22]
        ///Debug MCU reset
        dbgmcurst: u1 = 0,
        _unused23: u9 = 0,
    };
    ///APB2 peripheral reset register
    ///(RCC_APB2RSTR)
    pub const apb2rstr = Register(apb2rstr_val).init(0x40021000 + 0xC);

    //////////////////////////
    ///APB1RSTR
    const apb1rstr_val = packed struct {
        _unused0: u1 = 0,
        ///TIM3RST [1:1]
        ///Timer 3 reset
        tim3rst: packed enum(u1) {
            ///Reset the selected module
            reset = 1,
            _zero = 0,
        } = ._zero,
        _unused2: u2 = 0,
        ///TIM6RST [4:4]
        ///Timer 6 reset
        tim6rst: u1 = 0,
        ///TIM7RST [5:5]
        ///TIM7 timer reset
        tim7rst: u1 = 0,
        _unused6: u2 = 0,
        ///TIM14RST [8:8]
        ///Timer 14 reset
        tim14rst: u1 = 0,
        _unused9: u2 = 0,
        ///WWDGRST [11:11]
        ///Window watchdog reset
        wwdgrst: u1 = 0,
        _unused12: u2 = 0,
        ///SPI2RST [14:14]
        ///SPI2 reset
        spi2rst: u1 = 0,
        _unused15: u2 = 0,
        ///USART2RST [17:17]
        ///USART 2 reset
        usart2rst: u1 = 0,
        ///USART3RST [18:18]
        ///USART3 reset
        usart3rst: u1 = 0,
        ///USART4RST [19:19]
        ///USART4 reset
        usart4rst: u1 = 0,
        ///USART5RST [20:20]
        ///USART5 reset
        usart5rst: u1 = 0,
        ///I2C1RST [21:21]
        ///I2C1 reset
        i2c1rst: u1 = 0,
        ///I2C2RST [22:22]
        ///I2C2 reset
        i2c2rst: u1 = 0,
        ///USBRST [23:23]
        ///USB interface reset
        usbrst: u1 = 0,
        _unused24: u4 = 0,
        ///PWRRST [28:28]
        ///Power interface reset
        pwrrst: u1 = 0,
        _unused29: u3 = 0,
    };
    ///APB1 peripheral reset register
    ///(RCC_APB1RSTR)
    pub const apb1rstr = Register(apb1rstr_val).init(0x40021000 + 0x10);

    //////////////////////////
    ///AHBENR
    const ahbenr_val = packed struct {
        ///DMAEN [0:0]
        ///DMA clock enable
        dmaen: packed enum(u1) {
            ///The selected clock is disabled
            disabled = 0,
            ///The selected clock is enabled
            enabled = 1,
        } = .disabled,
        _unused1: u1 = 0,
        ///SRAMEN [2:2]
        ///SRAM interface clock
        ///enable
        sramen: u1 = 1,
        _unused3: u1 = 0,
        ///FLITFEN [4:4]
        ///FLITF clock enable
        flitfen: u1 = 1,
        _unused5: u1 = 0,
        ///CRCEN [6:6]
        ///CRC clock enable
        crcen: u1 = 0,
        _unused7: u10 = 0,
        ///IOPAEN [17:17]
        ///I/O port A clock enable
        iopaen: u1 = 0,
        ///IOPBEN [18:18]
        ///I/O port B clock enable
        iopben: u1 = 0,
        ///IOPCEN [19:19]
        ///I/O port C clock enable
        iopcen: u1 = 0,
        ///IOPDEN [20:20]
        ///I/O port D clock enable
        iopden: u1 = 0,
        _unused21: u1 = 0,
        ///IOPFEN [22:22]
        ///I/O port F clock enable
        iopfen: u1 = 0,
        _unused23: u9 = 0,
    };
    ///AHB Peripheral Clock enable register
    ///(RCC_AHBENR)
    pub const ahbenr = Register(ahbenr_val).init(0x40021000 + 0x14);

    //////////////////////////
    ///APB2ENR
    const apb2enr_val = packed struct {
        ///SYSCFGEN [0:0]
        ///SYSCFG clock enable
        syscfgen: packed enum(u1) {
            ///The selected clock is disabled
            disabled = 0,
            ///The selected clock is enabled
            enabled = 1,
        } = .disabled,
        _unused1: u4 = 0,
        ///USART6EN [5:5]
        ///USART6 clock enable
        usart6en: u1 = 0,
        _unused6: u3 = 0,
        ///ADCEN [9:9]
        ///ADC 1 interface clock
        ///enable
        adcen: u1 = 0,
        _unused10: u1 = 0,
        ///TIM1EN [11:11]
        ///TIM1 Timer clock enable
        tim1en: u1 = 0,
        ///SPI1EN [12:12]
        ///SPI 1 clock enable
        spi1en: u1 = 0,
        _unused13: u1 = 0,
        ///USART1EN [14:14]
        ///USART1 clock enable
        usart1en: u1 = 0,
        _unused15: u1 = 0,
        ///TIM15EN [16:16]
        ///TIM15 timer clock enable
        tim15en: u1 = 0,
        ///TIM16EN [17:17]
        ///TIM16 timer clock enable
        tim16en: u1 = 0,
        ///TIM17EN [18:18]
        ///TIM17 timer clock enable
        tim17en: u1 = 0,
        _unused19: u3 = 0,
        ///DBGMCUEN [22:22]
        ///MCU debug module clock
        ///enable
        dbgmcuen: u1 = 0,
        _unused23: u9 = 0,
    };
    ///APB2 peripheral clock enable register
    ///(RCC_APB2ENR)
    pub const apb2enr = Register(apb2enr_val).init(0x40021000 + 0x18);

    //////////////////////////
    ///APB1ENR
    const apb1enr_val = packed struct {
        _unused0: u1 = 0,
        ///TIM3EN [1:1]
        ///Timer 3 clock enable
        tim3en: packed enum(u1) {
            ///The selected clock is disabled
            disabled = 0,
            ///The selected clock is enabled
            enabled = 1,
        } = .disabled,
        _unused2: u2 = 0,
        ///TIM6EN [4:4]
        ///Timer 6 clock enable
        tim6en: u1 = 0,
        ///TIM7EN [5:5]
        ///TIM7 timer clock enable
        tim7en: u1 = 0,
        _unused6: u2 = 0,
        ///TIM14EN [8:8]
        ///Timer 14 clock enable
        tim14en: u1 = 0,
        _unused9: u2 = 0,
        ///WWDGEN [11:11]
        ///Window watchdog clock
        ///enable
        wwdgen: u1 = 0,
        _unused12: u2 = 0,
        ///SPI2EN [14:14]
        ///SPI 2 clock enable
        spi2en: u1 = 0,
        _unused15: u2 = 0,
        ///USART2EN [17:17]
        ///USART 2 clock enable
        usart2en: u1 = 0,
        ///USART3EN [18:18]
        ///USART3 clock enable
        usart3en: u1 = 0,
        ///USART4EN [19:19]
        ///USART4 clock enable
        usart4en: u1 = 0,
        ///USART5EN [20:20]
        ///USART5 clock enable
        usart5en: u1 = 0,
        ///I2C1EN [21:21]
        ///I2C 1 clock enable
        i2c1en: u1 = 0,
        ///I2C2EN [22:22]
        ///I2C 2 clock enable
        i2c2en: u1 = 0,
        ///USBEN [23:23]
        ///USB interface clock enable
        usben: u1 = 0,
        _unused24: u4 = 0,
        ///PWREN [28:28]
        ///Power interface clock
        ///enable
        pwren: u1 = 0,
        _unused29: u3 = 0,
    };
    ///APB1 peripheral clock enable register
    ///(RCC_APB1ENR)
    pub const apb1enr = Register(apb1enr_val).init(0x40021000 + 0x1C);

    //////////////////////////
    ///BDCR
    const bdcr_val_read = packed struct {
        ///LSEON [0:0]
        ///External Low Speed oscillator
        ///enable
        lseon: u1 = 0,
        ///LSERDY [1:1]
        ///External Low Speed oscillator
        ///ready
        lserdy: packed enum(u1) {
            ///LSE oscillator not ready
            not_ready = 0,
            ///LSE oscillator ready
            ready = 1,
        } = .not_ready,
        ///LSEBYP [2:2]
        ///External Low Speed oscillator
        ///bypass
        lsebyp: u1 = 0,
        ///LSEDRV [3:4]
        ///LSE oscillator drive
        ///capability
        lsedrv: u2 = 0,
        _unused5: u3 = 0,
        ///RTCSEL [8:9]
        ///RTC clock source selection
        rtcsel: u2 = 0,
        _unused10: u5 = 0,
        ///RTCEN [15:15]
        ///RTC clock enable
        rtcen: u1 = 0,
        ///BDRST [16:16]
        ///Backup domain software
        ///reset
        bdrst: u1 = 0,
        _unused17: u15 = 0,
    };
    const bdcr_val_write = packed struct {
        ///LSEON [0:0]
        ///External Low Speed oscillator
        ///enable
        lseon: u1 = 0,
        ///LSERDY [1:1]
        ///External Low Speed oscillator
        ///ready
        lserdy: u1 = 0,
        ///LSEBYP [2:2]
        ///External Low Speed oscillator
        ///bypass
        lsebyp: u1 = 0,
        ///LSEDRV [3:4]
        ///LSE oscillator drive
        ///capability
        lsedrv: u2 = 0,
        _unused5: u3 = 0,
        ///RTCSEL [8:9]
        ///RTC clock source selection
        rtcsel: u2 = 0,
        _unused10: u5 = 0,
        ///RTCEN [15:15]
        ///RTC clock enable
        rtcen: u1 = 0,
        ///BDRST [16:16]
        ///Backup domain software
        ///reset
        bdrst: u1 = 0,
        _unused17: u15 = 0,
    };
    ///Backup domain control register
    ///(RCC_BDCR)
    pub const bdcr = Register(bdcr_val).init(0x40021000 + 0x20);

    //////////////////////////
    ///CSR
    const csr_val_read = packed struct {
        ///LSION [0:0]
        ///Internal low speed oscillator
        ///enable
        lsion: u1 = 0,
        ///LSIRDY [1:1]
        ///Internal low speed oscillator
        ///ready
        lsirdy: packed enum(u1) {
            ///LSI oscillator not ready
            not_ready = 0,
            ///LSI oscillator ready
            ready = 1,
        } = .not_ready,
        _unused2: u21 = 0,
        ///V18PWRRSTF [23:23]
        ///1.8 V domain reset flag
        v18pwrrstf: u1 = 0,
        ///RMVF [24:24]
        ///Remove reset flag
        rmvf: u1 = 0,
        ///OBLRSTF [25:25]
        ///Option byte loader reset
        ///flag
        oblrstf: packed enum(u1) {
            ///No reset has occured
            no_reset = 0,
            ///A reset has occured
            reset = 1,
        } = .no_reset,
        ///PINRSTF [26:26]
        ///PIN reset flag
        pinrstf: u1 = 1,
        ///PORRSTF [27:27]
        ///POR/PDR reset flag
        porrstf: u1 = 1,
        ///SFTRSTF [28:28]
        ///Software reset flag
        sftrstf: u1 = 0,
        ///IWDGRSTF [29:29]
        ///Independent watchdog reset
        ///flag
        iwdgrstf: u1 = 0,
        ///WWDGRSTF [30:30]
        ///Window watchdog reset flag
        wwdgrstf: u1 = 0,
        ///LPWRRSTF [31:31]
        ///Low-power reset flag
        lpwrrstf: u1 = 0,
    };
    const csr_val_write = packed struct {
        ///LSION [0:0]
        ///Internal low speed oscillator
        ///enable
        lsion: u1 = 0,
        ///LSIRDY [1:1]
        ///Internal low speed oscillator
        ///ready
        lsirdy: u1 = 0,
        _unused2: u21 = 0,
        ///V18PWRRSTF [23:23]
        ///1.8 V domain reset flag
        v18pwrrstf: u1 = 0,
        ///RMVF [24:24]
        ///Remove reset flag
        rmvf: packed enum(u1) {
            ///Clears the reset flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///OBLRSTF [25:25]
        ///Option byte loader reset
        ///flag
        oblrstf: u1 = 0,
        ///PINRSTF [26:26]
        ///PIN reset flag
        pinrstf: u1 = 1,
        ///PORRSTF [27:27]
        ///POR/PDR reset flag
        porrstf: u1 = 1,
        ///SFTRSTF [28:28]
        ///Software reset flag
        sftrstf: u1 = 0,
        ///IWDGRSTF [29:29]
        ///Independent watchdog reset
        ///flag
        iwdgrstf: u1 = 0,
        ///WWDGRSTF [30:30]
        ///Window watchdog reset flag
        wwdgrstf: u1 = 0,
        ///LPWRRSTF [31:31]
        ///Low-power reset flag
        lpwrrstf: u1 = 0,
    };
    ///Control/status register
    ///(RCC_CSR)
    pub const csr = Register(csr_val).init(0x40021000 + 0x24);

    //////////////////////////
    ///AHBRSTR
    const ahbrstr_val = packed struct {
        _unused0: u17 = 0,
        ///IOPARST [17:17]
        ///I/O port A reset
        ioparst: packed enum(u1) {
            ///Reset the selected module
            reset = 1,
            _zero = 0,
        } = ._zero,
        ///IOPBRST [18:18]
        ///I/O port B reset
        iopbrst: u1 = 0,
        ///IOPCRST [19:19]
        ///I/O port C reset
        iopcrst: u1 = 0,
        ///IOPDRST [20:20]
        ///I/O port D reset
        iopdrst: u1 = 0,
        _unused21: u1 = 0,
        ///IOPFRST [22:22]
        ///I/O port F reset
        iopfrst: u1 = 0,
        _unused23: u9 = 0,
    };
    ///AHB peripheral reset register
    pub const ahbrstr = Register(ahbrstr_val).init(0x40021000 + 0x28);

    //////////////////////////
    ///CFGR2
    const cfgr2_val = packed struct {
        ///PREDIV [0:3]
        ///PREDIV division factor
        prediv: packed enum(u4) {
            ///PREDIV input clock not divided
            div1 = 0,
            ///PREDIV input clock divided by 2
            div2 = 1,
            ///PREDIV input clock divided by 3
            div3 = 2,
            ///PREDIV input clock divided by 4
            div4 = 3,
            ///PREDIV input clock divided by 5
            div5 = 4,
            ///PREDIV input clock divided by 6
            div6 = 5,
            ///PREDIV input clock divided by 7
            div7 = 6,
            ///PREDIV input clock divided by 8
            div8 = 7,
            ///PREDIV input clock divided by 9
            div9 = 8,
            ///PREDIV input clock divided by 10
            div10 = 9,
            ///PREDIV input clock divided by 11
            div11 = 10,
            ///PREDIV input clock divided by 12
            div12 = 11,
            ///PREDIV input clock divided by 13
            div13 = 12,
            ///PREDIV input clock divided by 14
            div14 = 13,
            ///PREDIV input clock divided by 15
            div15 = 14,
            ///PREDIV input clock divided by 16
            div16 = 15,
        } = .div1,
        _unused4: u28 = 0,
    };
    ///Clock configuration register 2
    pub const cfgr2 = Register(cfgr2_val).init(0x40021000 + 0x2C);

    //////////////////////////
    ///CFGR3
    const cfgr3_val = packed struct {
        ///USART1SW [0:1]
        ///USART1 clock source
        ///selection
        usart1sw: packed enum(u2) {
            ///PCLK selected as USART clock source
            pclk = 0,
            ///SYSCLK selected as USART clock source
            sysclk = 1,
            ///LSE selected as USART clock source
            lse = 2,
            ///HSI selected as USART clock source
            hsi = 3,
        } = .pclk,
        _unused2: u2 = 0,
        ///I2C1SW [4:4]
        ///I2C1 clock source
        ///selection
        i2c1sw: packed enum(u1) {
            ///HSI clock selected as I2C clock source
            hsi = 0,
            ///SYSCLK clock selected as I2C clock source
            sysclk = 1,
        } = .hsi,
        _unused5: u2 = 0,
        ///USBSW [7:7]
        ///USB clock source selection
        usbsw: packed enum(u1) {
            ///USB clock disabled
            disabled = 0,
            ///PLL clock selected as USB clock source
            pllclk = 1,
        } = .disabled,
        ///ADCSW [8:8]
        ///ADCSW is deprecated. See ADC field in CFGR2 register.
        adcsw: u1 = 0,
        _unused9: u7 = 0,
        ///USART2SW [16:17]
        ///USART2 clock source
        ///selection
        usart2sw: u2 = 0,
        ///USART3SW [18:19]
        ///USART3 clock source
        usart3sw: u2 = 0,
        _unused20: u12 = 0,
    };
    ///Clock configuration register 3
    pub const cfgr3 = Register(cfgr3_val).init(0x40021000 + 0x30);

    //////////////////////////
    ///CR2
    const cr2_val_read = packed struct {
        ///HSI14ON [0:0]
        ///HSI14 clock enable
        hsi14on: u1 = 0,
        ///HSI14RDY [1:1]
        ///HR14 clock ready flag
        hsi14rdy: packed enum(u1) {
            ///HSI14 oscillator not ready
            not_ready = 0,
            ///HSI14 oscillator ready
            ready = 1,
        } = .not_ready,
        ///HSI14DIS [2:2]
        ///HSI14 clock request from ADC
        ///disable
        hsi14dis: u1 = 0,
        ///HSI14TRIM [3:7]
        ///HSI14 clock trimming
        hsi14trim: u5 = 16,
        ///HSI14CAL [8:15]
        ///HSI14 clock calibration
        hsi14cal: u8 = 0,
        ///HSI48ON [16:16]
        ///HSI48 clock enable
        hsi48on: u1 = 0,
        ///HSI48RDY [17:17]
        ///HSI48 clock ready flag
        hsi48rdy: packed enum(u1) {
            ///HSI48 oscillator ready
            not_ready = 0,
            ///HSI48 oscillator ready
            ready = 1,
        } = .not_ready,
        _unused18: u6 = 0,
        ///HSI48CAL [24:31]
        ///HSI48 factory clock
        ///calibration
        hsi48cal: u8 = 0,
    };
    const cr2_val_write = packed struct {
        ///HSI14ON [0:0]
        ///HSI14 clock enable
        hsi14on: u1 = 0,
        ///HSI14RDY [1:1]
        ///HR14 clock ready flag
        hsi14rdy: u1 = 0,
        ///HSI14DIS [2:2]
        ///HSI14 clock request from ADC
        ///disable
        hsi14dis: u1 = 0,
        ///HSI14TRIM [3:7]
        ///HSI14 clock trimming
        hsi14trim: u5 = 16,
        ///HSI14CAL [8:15]
        ///HSI14 clock calibration
        hsi14cal: u8 = 0,
        ///HSI48ON [16:16]
        ///HSI48 clock enable
        hsi48on: u1 = 0,
        ///HSI48RDY [17:17]
        ///HSI48 clock ready flag
        hsi48rdy: u1 = 0,
        _unused18: u6 = 0,
        ///HSI48CAL [24:31]
        ///HSI48 factory clock
        ///calibration
        hsi48cal: u8 = 0,
    };
    ///Clock control register 2
    pub const cr2 = Register(cr2_val).init(0x40021000 + 0x34);
};

///System configuration controller
pub const syscfg = struct {

    //////////////////////////
    ///CFGR1
    const cfgr1_val = packed struct {
        ///MEM_MODE [0:1]
        ///Memory mapping selection
        ///bits
        mem_mode: packed enum(u2) {
            ///Main Flash memory mapped at 0x0000_0000
            main_flash = 0,
            ///System Flash memory mapped at 0x0000_0000
            system_flash = 1,
            ///Main Flash memory mapped at 0x0000_0000
            main_flash2 = 2,
            ///Embedded SRAM mapped at 0x0000_0000
            sram = 3,
        } = .main_flash,
        _unused2: u2 = 0,
        ///PA11_PA12_RMP [4:4]
        ///PA11 and PA12 remapping bit for small packages (28 and 20 pins)
        pa11_pa12_rmp: packed enum(u1) {
            ///Pin pair PA9/PA10 mapped on the pins
            not_remapped = 0,
            ///Pin pair PA11/PA12 mapped instead of PA9/PA10
            remapped = 1,
        } = .not_remapped,
        _unused5: u3 = 0,
        ///ADC_DMA_RMP [8:8]
        ///ADC DMA remapping bit
        adc_dma_rmp: packed enum(u1) {
            ///ADC DMA request mapped on DMA channel 1
            not_remapped = 0,
            ///ADC DMA request mapped on DMA channel 2
            remapped = 1,
        } = .not_remapped,
        ///USART1_TX_DMA_RMP [9:9]
        ///USART1_TX DMA remapping
        ///bit
        usart1_tx_dma_rmp: packed enum(u1) {
            ///USART1_TX DMA request mapped on DMA channel 2
            not_remapped = 0,
            ///USART1_TX DMA request mapped on DMA channel 4
            remapped = 1,
        } = .not_remapped,
        ///USART1_RX_DMA_RMP [10:10]
        ///USART1_RX DMA request remapping
        ///bit
        usart1_rx_dma_rmp: packed enum(u1) {
            ///USART1_RX DMA request mapped on DMA channel 3
            not_remapped = 0,
            ///USART1_RX DMA request mapped on DMA channel 5
            remapped = 1,
        } = .not_remapped,
        ///TIM16_DMA_RMP [11:11]
        ///TIM16 DMA request remapping
        ///bit
        tim16_dma_rmp: packed enum(u1) {
            ///TIM16_CH1 and TIM16_UP DMA request mapped on DMA channel 3
            not_remapped = 0,
            ///TIM16_CH1 and TIM16_UP DMA request mapped on DMA channel 4
            remapped = 1,
        } = .not_remapped,
        ///TIM17_DMA_RMP [12:12]
        ///TIM17 DMA request remapping
        ///bit
        tim17_dma_rmp: packed enum(u1) {
            ///TIM17_CH1 and TIM17_UP DMA request mapped on DMA channel 1
            not_remapped = 0,
            ///TIM17_CH1 and TIM17_UP DMA request mapped on DMA channel 2
            remapped = 1,
        } = .not_remapped,
        _unused13: u3 = 0,
        ///I2C_PB6_FMP [16:16]
        ///Fast Mode Plus (FM plus) driving
        ///capability activation bits.
        i2c_pb6_fmp: packed enum(u1) {
            ///PB6 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PB6 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        ///I2C_PB7_FMP [17:17]
        ///Fast Mode Plus (FM+) driving capability
        ///activation bits.
        i2c_pb7_fmp: packed enum(u1) {
            ///PB7 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PB7 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        ///I2C_PB8_FMP [18:18]
        ///Fast Mode Plus (FM+) driving capability
        ///activation bits.
        i2c_pb8_fmp: packed enum(u1) {
            ///PB8 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PB8 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        ///I2C_PB9_FMP [19:19]
        ///Fast Mode Plus (FM+) driving capability
        ///activation bits.
        i2c_pb9_fmp: packed enum(u1) {
            ///PB9 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PB9 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        ///I2C1_FMP [20:20]
        ///FM+ driving capability activation for
        ///I2C1
        i2c1_fmp: packed enum(u1) {
            ///FM+ mode is controlled by I2C_Pxx_FMP bits only
            standard = 0,
            ///FM+ mode is enabled on all I2C1 pins selected through selection bits in GPIOx_AFR registers
            fmp = 1,
        } = .standard,
        _unused21: u1 = 0,
        ///I2C_PA9_FMP [22:22]
        ///Fast Mode Plus (FM+) driving capability activation bits
        i2c_pa9_fmp: packed enum(u1) {
            ///PA9 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PA9 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        ///I2C_PA10_FMP [23:23]
        ///Fast Mode Plus (FM+) driving capability activation bits
        i2c_pa10_fmp: packed enum(u1) {
            ///PA10 pin operate in standard mode
            standard = 0,
            ///I2C FM+ mode enabled on PA10 and the Speed control is bypassed
            fmp = 1,
        } = .standard,
        _unused24: u2 = 0,
        ///USART3_DMA_RMP [26:26]
        ///USART3 DMA request remapping
        ///bit
        usart3_dma_rmp: packed enum(u1) {
            ///USART3_RX and USART3_TX DMA requests mapped on DMA channel 6 and 7 respectively (or simply disabled on STM32F0x0)
            not_remapped = 0,
            ///USART3_RX and USART3_TX DMA requests mapped on DMA channel 3 and 2 respectively
            remapped = 1,
        } = .not_remapped,
        _unused27: u5 = 0,
    };
    ///configuration register 1
    pub const cfgr1 = Register(cfgr1_val).init(0x40010000 + 0x0);

    //////////////////////////
    ///EXTICR1
    const exticr1_val = packed struct {
        ///EXTI0 [0:3]
        ///EXTI 0 configuration bits
        exti0: packed enum(u4) {
            ///Select PA0 as the source input for the EXTI0 external interrupt
            pa0 = 0,
            ///Select PB0 as the source input for the EXTI0 external interrupt
            pb0 = 1,
            ///Select PC0 as the source input for the EXTI0 external interrupt
            pc0 = 2,
            ///Select PD0 as the source input for the EXTI0 external interrupt
            pd0 = 3,
            ///Select PF0 as the source input for the EXTI0 external interrupt
            pf0 = 5,
        } = .pa0,
        ///EXTI1 [4:7]
        ///EXTI 1 configuration bits
        exti1: packed enum(u4) {
            ///Select PA1 as the source input for the EXTI1 external interrupt
            pa1 = 0,
            ///Select PB1 as the source input for the EXTI1 external interrupt
            pb1 = 1,
            ///Select PC1 as the source input for the EXTI1 external interrupt
            pc1 = 2,
            ///Select PD1 as the source input for the EXTI1 external interrupt
            pd1 = 3,
            ///Select PF1 as the source input for the EXTI1 external interrupt
            pf1 = 5,
        } = .pa1,
        ///EXTI2 [8:11]
        ///EXTI 2 configuration bits
        exti2: packed enum(u4) {
            ///Select PA2 as the source input for the EXTI2 external interrupt
            pa2 = 0,
            ///Select PB2 as the source input for the EXTI2 external interrupt
            pb2 = 1,
            ///Select PC2 as the source input for the EXTI2 external interrupt
            pc2 = 2,
            ///Select PD2 as the source input for the EXTI2 external interrupt
            pd2 = 3,
            ///Select PF2 as the source input for the EXTI2 external interrupt
            pf2 = 5,
        } = .pa2,
        ///EXTI3 [12:15]
        ///EXTI 3 configuration bits
        exti3: packed enum(u4) {
            ///Select PA3 as the source input for the EXTI3 external interrupt
            pa3 = 0,
            ///Select PB3 as the source input for the EXTI3 external interrupt
            pb3 = 1,
            ///Select PC3 as the source input for the EXTI3 external interrupt
            pc3 = 2,
            ///Select PD3 as the source input for the EXTI3 external interrupt
            pd3 = 3,
            ///Select PF3 as the source input for the EXTI3 external interrupt
            pf3 = 5,
        } = .pa3,
        _unused16: u16 = 0,
    };
    ///external interrupt configuration register
    ///1
    pub const exticr1 = Register(exticr1_val).init(0x40010000 + 0x8);

    //////////////////////////
    ///EXTICR2
    const exticr2_val = packed struct {
        ///EXTI4 [0:3]
        ///EXTI 4 configuration bits
        exti4: packed enum(u4) {
            ///Select PA4 as the source input for the EXTI4 external interrupt
            pa4 = 0,
            ///Select PB4 as the source input for the EXTI4 external interrupt
            pb4 = 1,
            ///Select PC4 as the source input for the EXTI4 external interrupt
            pc4 = 2,
            ///Select PD4 as the source input for the EXTI4 external interrupt
            pd4 = 3,
            ///Select PF4 as the source input for the EXTI4 external interrupt
            pf4 = 5,
        } = .pa4,
        ///EXTI5 [4:7]
        ///EXTI 5 configuration bits
        exti5: packed enum(u4) {
            ///Select PA5 as the source input for the EXTI5 external interrupt
            pa5 = 0,
            ///Select PB5 as the source input for the EXTI5 external interrupt
            pb5 = 1,
            ///Select PC5 as the source input for the EXTI5 external interrupt
            pc5 = 2,
            ///Select PD5 as the source input for the EXTI5 external interrupt
            pd5 = 3,
            ///Select PF5 as the source input for the EXTI5 external interrupt
            pf5 = 5,
        } = .pa5,
        ///EXTI6 [8:11]
        ///EXTI 6 configuration bits
        exti6: packed enum(u4) {
            ///Select PA6 as the source input for the EXTI6 external interrupt
            pa6 = 0,
            ///Select PB6 as the source input for the EXTI6 external interrupt
            pb6 = 1,
            ///Select PC6 as the source input for the EXTI6 external interrupt
            pc6 = 2,
            ///Select PD6 as the source input for the EXTI6 external interrupt
            pd6 = 3,
            ///Select PF6 as the source input for the EXTI6 external interrupt
            pf6 = 5,
        } = .pa6,
        ///EXTI7 [12:15]
        ///EXTI 7 configuration bits
        exti7: packed enum(u4) {
            ///Select PA7 as the source input for the EXTI7 external interrupt
            pa7 = 0,
            ///Select PB7 as the source input for the EXTI7 external interrupt
            pb7 = 1,
            ///Select PC7 as the source input for the EXTI7 external interrupt
            pc7 = 2,
            ///Select PD7 as the source input for the EXTI7 external interrupt
            pd7 = 3,
            ///Select PF7 as the source input for the EXTI7 external interrupt
            pf7 = 5,
        } = .pa7,
        _unused16: u16 = 0,
    };
    ///external interrupt configuration register
    ///2
    pub const exticr2 = Register(exticr2_val).init(0x40010000 + 0xC);

    //////////////////////////
    ///EXTICR3
    const exticr3_val = packed struct {
        ///EXTI8 [0:3]
        ///EXTI 8 configuration bits
        exti8: packed enum(u4) {
            ///Select PA8 as the source input for the EXTI8 external interrupt
            pa8 = 0,
            ///Select PB8 as the source input for the EXTI8 external interrupt
            pb8 = 1,
            ///Select PC8 as the source input for the EXTI8 external interrupt
            pc8 = 2,
            ///Select PD8 as the source input for the EXTI8 external interrupt
            pd8 = 3,
            ///Select PF8 as the source input for the EXTI8 external interrupt
            pf8 = 5,
        } = .pa8,
        ///EXTI9 [4:7]
        ///EXTI 9 configuration bits
        exti9: packed enum(u4) {
            ///Select PA9 as the source input for the EXTI9 external interrupt
            pa9 = 0,
            ///Select PB9 as the source input for the EXTI9 external interrupt
            pb9 = 1,
            ///Select PC9 as the source input for the EXTI9 external interrupt
            pc9 = 2,
            ///Select PD9 as the source input for the EXTI9 external interrupt
            pd9 = 3,
            ///Select PF9 as the source input for the EXTI9 external interrupt
            pf9 = 5,
        } = .pa9,
        ///EXTI10 [8:11]
        ///EXTI 10 configuration bits
        exti10: packed enum(u4) {
            ///Select PA10 as the source input for the EXTI10 external interrupt
            pa10 = 0,
            ///Select PB10 as the source input for the EXTI10 external interrupt
            pb10 = 1,
            ///Select PC10 as the source input for the EXTI10 external interrupt
            pc10 = 2,
            ///Select PD10 as the source input for the EXTI10 external interrupt
            pd10 = 3,
            ///Select PF10 as the source input for the EXTI10 external interrupt
            pf10 = 5,
        } = .pa10,
        ///EXTI11 [12:15]
        ///EXTI 11 configuration bits
        exti11: packed enum(u4) {
            ///Select PA11 as the source input for the EXTI11 external interrupt
            pa11 = 0,
            ///Select PB11 as the source input for the EXTI11 external interrupt
            pb11 = 1,
            ///Select PC11 as the source input for the EXTI11 external interrupt
            pc11 = 2,
            ///Select PD11 as the source input for the EXTI11 external interrupt
            pd11 = 3,
            ///Select PF11 as the source input for the EXTI11 external interrupt
            pf11 = 5,
        } = .pa11,
        _unused16: u16 = 0,
    };
    ///external interrupt configuration register
    ///3
    pub const exticr3 = Register(exticr3_val).init(0x40010000 + 0x10);

    //////////////////////////
    ///EXTICR4
    const exticr4_val = packed struct {
        ///EXTI12 [0:3]
        ///EXTI 12 configuration bits
        exti12: packed enum(u4) {
            ///Select PA12 as the source input for the EXTI12 external interrupt
            pa12 = 0,
            ///Select PB12 as the source input for the EXTI12 external interrupt
            pb12 = 1,
            ///Select PC12 as the source input for the EXTI12 external interrupt
            pc12 = 2,
            ///Select PD12 as the source input for the EXTI12 external interrupt
            pd12 = 3,
            ///Select PF12 as the source input for the EXTI12 external interrupt
            pf12 = 5,
        } = .pa12,
        ///EXTI13 [4:7]
        ///EXTI 13 configuration bits
        exti13: packed enum(u4) {
            ///Select PA13 as the source input for the EXTI13 external interrupt
            pa13 = 0,
            ///Select PB13 as the source input for the EXTI13 external interrupt
            pb13 = 1,
            ///Select PC13 as the source input for the EXTI13 external interrupt
            pc13 = 2,
            ///Select PD13 as the source input for the EXTI13 external interrupt
            pd13 = 3,
            ///Select PF13 as the source input for the EXTI13 external interrupt
            pf13 = 5,
        } = .pa13,
        ///EXTI14 [8:11]
        ///EXTI 14 configuration bits
        exti14: packed enum(u4) {
            ///Select PA14 as the source input for the EXTI14 external interrupt
            pa14 = 0,
            ///Select PB14 as the source input for the EXTI14 external interrupt
            pb14 = 1,
            ///Select PC14 as the source input for the EXTI14 external interrupt
            pc14 = 2,
            ///Select PD14 as the source input for the EXTI14 external interrupt
            pd14 = 3,
            ///Select PF14 as the source input for the EXTI14 external interrupt
            pf14 = 5,
        } = .pa14,
        ///EXTI15 [12:15]
        ///EXTI 15 configuration bits
        exti15: packed enum(u4) {
            ///Select PA15 as the source input for the EXTI15 external interrupt
            pa15 = 0,
            ///Select PB15 as the source input for the EXTI15 external interrupt
            pb15 = 1,
            ///Select PC15 as the source input for the EXTI15 external interrupt
            pc15 = 2,
            ///Select PD15 as the source input for the EXTI15 external interrupt
            pd15 = 3,
            ///Select PF15 as the source input for the EXTI15 external interrupt
            pf15 = 5,
        } = .pa15,
        _unused16: u16 = 0,
    };
    ///external interrupt configuration register
    ///4
    pub const exticr4 = Register(exticr4_val).init(0x40010000 + 0x14);

    //////////////////////////
    ///CFGR2
    const cfgr2_val_read = packed struct {
        ///LOCKUP_LOCK [0:0]
        ///Cortex-M0 LOCKUP bit enable
        ///bit
        lockup_lock: u1 = 0,
        ///SRAM_PARITY_LOCK [1:1]
        ///SRAM parity lock bit
        sram_parity_lock: u1 = 0,
        _unused2: u6 = 0,
        ///SRAM_PEF [8:8]
        ///SRAM parity flag
        sram_pef: packed enum(u1) {
            ///No SRAM parity error detected
            no_parity_error = 0,
            ///SRAM parity error detected
            parity_error_detected = 1,
        } = .no_parity_error,
        _unused9: u23 = 0,
    };
    const cfgr2_val_write = packed struct {
        ///LOCKUP_LOCK [0:0]
        ///Cortex-M0 LOCKUP bit enable
        ///bit
        lockup_lock: u1 = 0,
        ///SRAM_PARITY_LOCK [1:1]
        ///SRAM parity lock bit
        sram_parity_lock: u1 = 0,
        _unused2: u6 = 0,
        ///SRAM_PEF [8:8]
        ///SRAM parity flag
        sram_pef: packed enum(u1) {
            ///Clear SRAM parity error flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused9: u23 = 0,
    };
    ///configuration register 2
    pub const cfgr2 = RegisterRW(cfgr2_val_read, cfgr2_val_write).init(0x40010000 + 0x18);
};

///Analog-to-digital converter
pub const adc = struct {

    //////////////////////////
    ///ISR
    const isr_val_read = packed struct {
        ///ADRDY [0:0]
        ///ADC ready
        adrdy: packed enum(u1) {
            ///ADC not yet ready to start conversion
            not_ready = 0,
            ///ADC ready to start conversion
            ready = 1,
        } = .not_ready,
        ///EOSMP [1:1]
        ///End of sampling flag
        eosmp: packed enum(u1) {
            ///Not at the end of the samplings phase
            not_at_end = 0,
            ///End of sampling phase reached
            at_end = 1,
        } = .not_at_end,
        ///EOC [2:2]
        ///End of conversion flag
        eoc: packed enum(u1) {
            ///Channel conversion is not complete
            not_complete = 0,
            ///Channel conversion complete
            complete = 1,
        } = .not_complete,
        ///EOSEQ [3:3]
        ///End of sequence flag
        eoseq: packed enum(u1) {
            ///Conversion sequence is not complete
            not_complete = 0,
            ///Conversion sequence complete
            complete = 1,
        } = .not_complete,
        ///OVR [4:4]
        ///ADC overrun
        ovr: packed enum(u1) {
            ///No overrun occurred
            no_overrun = 0,
            ///Overrun occurred
            overrun = 1,
        } = .no_overrun,
        _unused5: u2 = 0,
        ///AWD [7:7]
        ///Analog watchdog flag
        awd: packed enum(u1) {
            ///No analog watchdog event occurred
            no_event = 0,
            ///Analog watchdog event occurred
            event = 1,
        } = .no_event,
        _unused8: u24 = 0,
    };
    const isr_val_write = packed struct {
        ///ADRDY [0:0]
        ///ADC ready
        adrdy: packed enum(u1) {
            ///Clear the ADC ready flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOSMP [1:1]
        ///End of sampling flag
        eosmp: packed enum(u1) {
            ///Clear the sampling phase flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOC [2:2]
        ///End of conversion flag
        eoc: packed enum(u1) {
            ///Clear the channel conversion flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOSEQ [3:3]
        ///End of sequence flag
        eoseq: packed enum(u1) {
            ///Clear the conversion sequence flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///OVR [4:4]
        ///ADC overrun
        ovr: packed enum(u1) {
            ///Clear the overrun flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u2 = 0,
        ///AWD [7:7]
        ///Analog watchdog flag
        awd: packed enum(u1) {
            ///Clear the analog watchdog event flag
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused8: u24 = 0,
    };
    ///interrupt and status register
    pub const isr = RegisterRW(isr_val_read, isr_val_write).init(0x40012400 + 0x0);

    //////////////////////////
    ///IER
    const ier_val = packed struct {
        ///ADRDYIE [0:0]
        ///ADC ready interrupt enable
        adrdyie: packed enum(u1) {
            ///ADC ready interrupt disabled
            disabled = 0,
            ///ADC ready interrupt enabled
            enabled = 1,
        } = .disabled,
        ///EOSMPIE [1:1]
        ///End of sampling flag interrupt
        ///enable
        eosmpie: packed enum(u1) {
            ///End of sampling interrupt disabled
            disabled = 0,
            ///End of sampling interrupt enabled
            enabled = 1,
        } = .disabled,
        ///EOCIE [2:2]
        ///End of conversion interrupt
        ///enable
        eocie: packed enum(u1) {
            ///End of conversion interrupt disabled
            disabled = 0,
            ///End of conversion interrupt enabled
            enabled = 1,
        } = .disabled,
        ///EOSEQIE [3:3]
        ///End of conversion sequence interrupt
        ///enable
        eoseqie: packed enum(u1) {
            ///End of conversion sequence interrupt disabled
            disabled = 0,
            ///End of conversion sequence interrupt enabled
            enabled = 1,
        } = .disabled,
        ///OVRIE [4:4]
        ///Overrun interrupt enable
        ovrie: packed enum(u1) {
            ///Overrun interrupt disabled
            disabled = 0,
            ///Overrun interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused5: u2 = 0,
        ///AWDIE [7:7]
        ///Analog watchdog interrupt
        ///enable
        awdie: packed enum(u1) {
            ///Analog watchdog interrupt disabled
            disabled = 0,
            ///Analog watchdog interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused8: u24 = 0,
    };
    ///interrupt enable register
    pub const ier = Register(ier_val).init(0x40012400 + 0x4);

    //////////////////////////
    ///CR
    const cr_val_read = packed struct {
        ///ADEN [0:0]
        ///ADC enable command
        aden: packed enum(u1) {
            ///ADC disabled
            disabled = 0,
            ///ADC enabled
            enabled = 1,
        } = .disabled,
        ///ADDIS [1:1]
        ///ADC disable command
        addis: packed enum(u1) {
            ///No disable command active
            not_disabling = 0,
            ///ADC disabling
            disabling = 1,
        } = .not_disabling,
        ///ADSTART [2:2]
        ///ADC start conversion
        ///command
        adstart: packed enum(u1) {
            ///No conversion ongoing
            not_active = 0,
            ///ADC operating and may be converting
            active = 1,
        } = .not_active,
        _unused3: u1 = 0,
        ///ADSTP [4:4]
        ///ADC stop conversion
        ///command
        adstp: packed enum(u1) {
            ///No stop command active
            not_stopping = 0,
            ///ADC stopping conversion
            stopping = 1,
        } = .not_stopping,
        _unused5: u26 = 0,
        ///ADCAL [31:31]
        ///ADC calibration
        adcal: packed enum(u1) {
            ///ADC calibration either not yet performed or completed
            not_calibrating = 0,
            ///ADC calibration in progress
            calibrating = 1,
        } = .not_calibrating,
    };
    const cr_val_write = packed struct {
        ///ADEN [0:0]
        ///ADC enable command
        aden: packed enum(u1) {
            ///Enable the ADC
            enabled = 1,
            _zero = 0,
        } = ._zero,
        ///ADDIS [1:1]
        ///ADC disable command
        addis: packed enum(u1) {
            ///Disable the ADC
            disable = 1,
            _zero = 0,
        } = ._zero,
        ///ADSTART [2:2]
        ///ADC start conversion
        ///command
        adstart: packed enum(u1) {
            ///Start the ADC conversion (may be delayed for hardware triggers)
            start_conversion = 1,
            _zero = 0,
        } = ._zero,
        _unused3: u1 = 0,
        ///ADSTP [4:4]
        ///ADC stop conversion
        ///command
        adstp: packed enum(u1) {
            ///Stop the active conversion
            stop_conversion = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u26 = 0,
        ///ADCAL [31:31]
        ///ADC calibration
        adcal: packed enum(u1) {
            ///Start the ADC calibration sequence
            start_calibration = 1,
            _zero = 0,
        } = ._zero,
    };
    ///control register
    pub const cr = RegisterRW(cr_val_read, cr_val_write).init(0x40012400 + 0x8);

    //////////////////////////
    ///CFGR1
    const cfgr1_val = packed struct {
        ///DMAEN [0:0]
        ///Direct memory access
        ///enable
        dmaen: packed enum(u1) {
            ///DMA mode disabled
            disabled = 0,
            ///DMA mode enabled
            enabled = 1,
        } = .disabled,
        ///DMACFG [1:1]
        ///Direct memery access
        ///configuration
        dmacfg: packed enum(u1) {
            ///DMA one shot mode
            one_shot = 0,
            ///DMA circular mode
            circular = 1,
        } = .one_shot,
        ///SCANDIR [2:2]
        ///Scan sequence direction
        scandir: packed enum(u1) {
            ///Upward scan (from CHSEL0 to CHSEL18)
            upward = 0,
            ///Backward scan (from CHSEL18 to CHSEL0)
            backward = 1,
        } = .upward,
        ///RES [3:4]
        ///Data resolution
        res: packed enum(u2) {
            ///12-bit (14 ADCCLK cycles)
            twelve_bit = 0,
            ///10-bit (13 ADCCLK cycles)
            ten_bit = 1,
            ///8-bit (11 ADCCLK cycles)
            eight_bit = 2,
            ///6-bit (9 ADCCLK cycles)
            six_bit = 3,
        } = .twelve_bit,
        ///ALIGN [5:5]
        ///Data alignment
        _align: packed enum(u1) {
            ///Right alignment
            right = 0,
            ///Left alignment
            left = 1,
        } = .right,
        ///EXTSEL [6:8]
        ///External trigger selection
        extsel: packed enum(u3) {
            ///Timer 1 TRGO Event
            tim1_trgo = 0,
            ///Timer 1 CC4 event
            tim1_cc4 = 1,
            ///Timer 3 TRGO event
            tim3_trgo = 3,
            ///Timer 15 TRGO event
            tim15_trgo = 4,
        } = .tim1_trgo,
        _unused9: u1 = 0,
        ///EXTEN [10:11]
        ///External trigger enable and polarity
        ///selection
        exten: packed enum(u2) {
            ///Trigger detection disabled
            disabled = 0,
            ///Trigger detection on the rising edge
            rising_edge = 1,
            ///Trigger detection on the falling edge
            falling_edge = 2,
            ///Trigger detection on both the rising and falling edges
            both_edges = 3,
        } = .disabled,
        ///OVRMOD [12:12]
        ///Overrun management mode
        ovrmod: packed enum(u1) {
            ///ADC_DR register is preserved with the old data when an overrun is detected
            preserved = 0,
            ///ADC_DR register is overwritten with the last conversion result when an overrun is detected
            overwritten = 1,
        } = .preserved,
        ///CONT [13:13]
        ///Single / continuous conversion
        ///mode
        cont: packed enum(u1) {
            ///Single conversion mode
            single = 0,
            ///Continuous conversion mode
            continuous = 1,
        } = .single,
        ///WAIT [14:14]
        ///Wait conversion mode
        wait: packed enum(u1) {
            ///Wait conversion mode off
            disabled = 0,
            ///Wait conversion mode on
            enabled = 1,
        } = .disabled,
        ///AUTOFF [15:15]
        ///Auto-off mode
        autoff: packed enum(u1) {
            ///Auto-off mode disabled
            disabled = 0,
            ///Auto-off mode enabled
            enabled = 1,
        } = .disabled,
        ///DISCEN [16:16]
        ///Discontinuous mode
        discen: packed enum(u1) {
            ///Discontinuous mode on regular channels disabled
            disabled = 0,
            ///Discontinuous mode on regular channels enabled
            enabled = 1,
        } = .disabled,
        _unused17: u5 = 0,
        ///AWDSGL [22:22]
        ///Enable the watchdog on a single channel
        ///or on all channels
        awdsgl: packed enum(u1) {
            ///Analog watchdog enabled on all channels
            all_channels = 0,
            ///Analog watchdog enabled on a single channel
            single_channel = 1,
        } = .all_channels,
        ///AWDEN [23:23]
        ///Analog watchdog enable
        awden: packed enum(u1) {
            ///Analog watchdog disabled on regular channels
            disabled = 0,
            ///Analog watchdog enabled on regular channels
            enabled = 1,
        } = .disabled,
        _unused24: u2 = 0,
        ///AWDCH [26:30]
        ///Analog watchdog channel
        ///selection
        awdch: u5 = 0,
        _unused31: u1 = 0,
    };
    ///configuration register 1
    pub const cfgr1 = Register(cfgr1_val).init(0x40012400 + 0xC);

    //////////////////////////
    ///CFGR2
    const cfgr2_val = packed struct {
        _unused0: u30 = 0,
        ///CKMODE [30:31]
        ///ADC clock mode
        ckmode: packed enum(u2) {
            ///Asynchronous clock mode
            adcclk = 0,
            ///Synchronous clock mode (PCLK/2)
            pclk_div2 = 1,
            ///Sychronous clock mode (PCLK/4)
            pclk_div4 = 2,
        } = .adcclk,
    };
    ///configuration register 2
    pub const cfgr2 = Register(cfgr2_val).init(0x40012400 + 0x10);

    //////////////////////////
    ///SMPR
    const smpr_val = packed struct {
        ///SMP [0:2]
        ///Sampling time selection
        smp: packed enum(u3) {
            ///1.5 cycles
            cycles1_5 = 0,
            ///7.5 cycles
            cycles7_5 = 1,
            ///13.5 cycles
            cycles13_5 = 2,
            ///28.5 cycles
            cycles28_5 = 3,
            ///41.5 cycles
            cycles41_5 = 4,
            ///55.5 cycles
            cycles55_5 = 5,
            ///71.5 cycles
            cycles71_5 = 6,
            ///239.5 cycles
            cycles239_5 = 7,
        } = .cycles1_5,
        _unused3: u29 = 0,
    };
    ///sampling time register
    pub const smpr = Register(smpr_val).init(0x40012400 + 0x14);

    //////////////////////////
    ///TR
    const tr_val = packed struct {
        ///LT [0:11]
        ///Analog watchdog lower
        ///threshold
        lt: u12 = 4095,
        _unused12: u4 = 0,
        ///HT [16:27]
        ///Analog watchdog higher
        ///threshold
        ht: u12 = 0,
        _unused28: u4 = 0,
    };
    ///watchdog threshold register
    pub const tr = Register(tr_val).init(0x40012400 + 0x20);

    //////////////////////////
    ///CHSELR
    const chselr_val = packed struct {
        ///CHSEL0 [0:0]
        ///Channel-x selection
        chsel0: u1 = 0,
        ///CHSEL1 [1:1]
        ///Channel-x selection
        chsel1: u1 = 0,
        ///CHSEL2 [2:2]
        ///Channel-x selection
        chsel2: u1 = 0,
        ///CHSEL3 [3:3]
        ///Channel-x selection
        chsel3: u1 = 0,
        ///CHSEL4 [4:4]
        ///Channel-x selection
        chsel4: u1 = 0,
        ///CHSEL5 [5:5]
        ///Channel-x selection
        chsel5: u1 = 0,
        ///CHSEL6 [6:6]
        ///Channel-x selection
        chsel6: u1 = 0,
        ///CHSEL7 [7:7]
        ///Channel-x selection
        chsel7: u1 = 0,
        ///CHSEL8 [8:8]
        ///Channel-x selection
        chsel8: u1 = 0,
        ///CHSEL9 [9:9]
        ///Channel-x selection
        chsel9: u1 = 0,
        ///CHSEL10 [10:10]
        ///Channel-x selection
        chsel10: u1 = 0,
        ///CHSEL11 [11:11]
        ///Channel-x selection
        chsel11: u1 = 0,
        ///CHSEL12 [12:12]
        ///Channel-x selection
        chsel12: u1 = 0,
        ///CHSEL13 [13:13]
        ///Channel-x selection
        chsel13: u1 = 0,
        ///CHSEL14 [14:14]
        ///Channel-x selection
        chsel14: u1 = 0,
        ///CHSEL15 [15:15]
        ///Channel-x selection
        chsel15: u1 = 0,
        ///CHSEL16 [16:16]
        ///Channel-x selection
        chsel16: u1 = 0,
        ///CHSEL17 [17:17]
        ///Channel-x selection
        chsel17: u1 = 0,
        ///CHSEL18 [18:18]
        ///Channel-x selection
        chsel18: packed enum(u1) {
            ///Input Channel is not selected for conversion
            not_selected = 0,
            ///Input Channel is selected for conversion
            selected = 1,
        } = .not_selected,
        _unused19: u13 = 0,
    };
    ///channel selection register
    pub const chselr = Register(chselr_val).init(0x40012400 + 0x28);

    //////////////////////////
    ///DR
    const dr_val = packed struct {
        ///DATA [0:15]
        ///Converted data
        data: u16 = 0,
        _unused16: u16 = 0,
    };
    ///data register
    pub const dr = RegisterRW(dr_val, void).init(0x40012400 + 0x40);

    //////////////////////////
    ///CCR
    const ccr_val = packed struct {
        _unused0: u22 = 0,
        ///VREFEN [22:22]
        ///Temperature sensor and VREFINT
        ///enable
        vrefen: packed enum(u1) {
            ///V_REFINT channel disabled
            disabled = 0,
            ///V_REFINT channel enabled
            enabled = 1,
        } = .disabled,
        ///TSEN [23:23]
        ///Temperature sensor enable
        tsen: packed enum(u1) {
            ///Temperature sensor disabled
            disabled = 0,
            ///Temperature sensor enabled
            enabled = 1,
        } = .disabled,
        _unused24: u8 = 0,
    };
    ///common configuration register
    pub const ccr = Register(ccr_val).init(0x40012400 + 0x308);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart1 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40013800 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40013800 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40013800 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40013800 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40013800 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40013800 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40013800 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40013800 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40013800 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40013800 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40013800 + 0x28);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart2 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40004400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40004400 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40004400 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40004400 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40004400 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40004400 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40004400 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40004400 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40004400 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40004400 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40004400 + 0x28);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart3 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40004800 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40004800 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40004800 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40004800 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40004800 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40004800 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40004800 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40004800 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40004800 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40004800 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40004800 + 0x28);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart4 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40004C00 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40004C00 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40004C00 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40004C00 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40004C00 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40004C00 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40004C00 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40004C00 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40004C00 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40004C00 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40004C00 + 0x28);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart6 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40011400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40011400 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40011400 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40011400 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40011400 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40011400 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40011400 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40011400 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40011400 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40011400 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40011400 + 0x28);
};

///Universal synchronous asynchronous receiver
///transmitter
pub const usart5 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///UE [0:0]
        ///USART enable
        ue: packed enum(u1) {
            ///UART is disabled
            disabled = 0,
            ///UART is enabled
            enabled = 1,
        } = .disabled,
        ///UESM [1:1]
        ///USART enable in Stop mode
        uesm: packed enum(u1) {
            ///USART not able to wake up the MCU from Stop mode
            disabled = 0,
            ///USART able to wake up the MCU from Stop mode
            enabled = 1,
        } = .disabled,
        ///RE [2:2]
        ///Receiver enable
        re: packed enum(u1) {
            ///Receiver is disabled
            disabled = 0,
            ///Receiver is enabled
            enabled = 1,
        } = .disabled,
        ///TE [3:3]
        ///Transmitter enable
        te: packed enum(u1) {
            ///Transmitter is disabled
            disabled = 0,
            ///Transmitter is enabled
            enabled = 1,
        } = .disabled,
        ///IDLEIE [4:4]
        ///IDLE interrupt enable
        idleie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever IDLE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///RXNEIE [5:5]
        ///RXNE interrupt enable
        rxneie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever ORE=1 or RXNE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TCIE [6:6]
        ///Transmission complete interrupt
        ///enable
        tcie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TC=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///TXEIE [7:7]
        ///interrupt enable
        txeie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever TXE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PEIE [8:8]
        ///PE interrupt enable
        peie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated whenever PE=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///PS [9:9]
        ///Parity selection
        ps: packed enum(u1) {
            ///Even parity
            even = 0,
            ///Odd parity
            odd = 1,
        } = .even,
        ///PCE [10:10]
        ///Parity control enable
        pce: packed enum(u1) {
            ///Parity control disabled
            disabled = 0,
            ///Parity control enabled
            enabled = 1,
        } = .disabled,
        ///WAKE [11:11]
        ///Receiver wakeup method
        wake: packed enum(u1) {
            ///Idle line
            idle = 0,
            ///Address mask
            address = 1,
        } = .idle,
        ///M0 [12:12]
        ///Word length
        m0: packed enum(u1) {
            ///1 start bit, 8 data bits, n stop bits
            bit8 = 0,
            ///1 start bit, 9 data bits, n stop bits
            bit9 = 1,
        } = .bit8,
        ///MME [13:13]
        ///Mute mode enable
        mme: packed enum(u1) {
            ///Receiver in active mode permanently
            disabled = 0,
            ///Receiver can switch between mute mode and active mode
            enabled = 1,
        } = .disabled,
        ///CMIE [14:14]
        ///Character match interrupt
        ///enable
        cmie: packed enum(u1) {
            ///Interrupt is disabled
            disabled = 0,
            ///Interrupt is generated when the CMF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///OVER8 [15:15]
        ///Oversampling mode
        over8: packed enum(u1) {
            ///Oversampling by 16
            oversampling16 = 0,
            ///Oversampling by 8
            oversampling8 = 1,
        } = .oversampling16,
        ///DEDT [16:20]
        ///Driver Enable deassertion
        ///time
        dedt: u5 = 0,
        ///DEAT [21:25]
        ///Driver Enable assertion
        ///time
        deat: u5 = 0,
        ///RTOIE [26:26]
        ///Receiver timeout interrupt
        ///enable
        rtoie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated when the RTOF bit is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///EOBIE [27:27]
        ///End of Block interrupt
        ///enable
        eobie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///A USART interrupt is generated when the EOBF flag is set in the ISR register
            enabled = 1,
        } = .disabled,
        ///M1 [28:28]
        ///Word length
        m1: packed enum(u1) {
            ///Use M0 to set the data bits
            m0 = 0,
            ///1 start bit, 7 data bits, n stop bits
            bit7 = 1,
        } = .m0,
        _unused29: u3 = 0,
    };
    ///Control register 1
    pub const cr1 = Register(cr1_val).init(0x40005000 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        _unused0: u4 = 0,
        ///ADDM7 [4:4]
        ///7-bit Address Detection/4-bit Address
        ///Detection
        addm7: packed enum(u1) {
            ///4-bit address detection
            bit4 = 0,
            ///7-bit address detection
            bit7 = 1,
        } = .bit4,
        ///LBDL [5:5]
        ///LIN break detection length
        lbdl: packed enum(u1) {
            ///10-bit break detection
            bit10 = 0,
            ///11-bit break detection
            bit11 = 1,
        } = .bit10,
        ///LBDIE [6:6]
        ///LIN break detection interrupt
        ///enable
        lbdie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever LBDF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused7: u1 = 0,
        ///LBCL [8:8]
        ///Last bit clock pulse
        lbcl: packed enum(u1) {
            ///The clock pulse of the last data bit is not output to the CK pin
            not_output = 0,
            ///The clock pulse of the last data bit is output to the CK pin
            output = 1,
        } = .not_output,
        ///CPHA [9:9]
        ///Clock phase
        cpha: packed enum(u1) {
            ///The first clock transition is the first data capture edge
            first = 0,
            ///The second clock transition is the first data capture edge
            second = 1,
        } = .first,
        ///CPOL [10:10]
        ///Clock polarity
        cpol: packed enum(u1) {
            ///Steady low value on CK pin outside transmission window
            low = 0,
            ///Steady high value on CK pin outside transmission window
            high = 1,
        } = .low,
        ///CLKEN [11:11]
        ///Clock enable
        clken: packed enum(u1) {
            ///CK pin disabled
            disabled = 0,
            ///CK pin enabled
            enabled = 1,
        } = .disabled,
        ///STOP [12:13]
        ///STOP bits
        stop: packed enum(u2) {
            ///1 stop bit
            stop1 = 0,
            ///0.5 stop bit
            stop0p5 = 1,
            ///2 stop bit
            stop2 = 2,
            ///1.5 stop bit
            stop1p5 = 3,
        } = .stop1,
        ///LINEN [14:14]
        ///LIN mode enable
        linen: packed enum(u1) {
            ///LIN mode disabled
            disabled = 0,
            ///LIN mode enabled
            enabled = 1,
        } = .disabled,
        ///SWAP [15:15]
        ///Swap TX/RX pins
        swap: packed enum(u1) {
            ///TX/RX pins are used as defined in standard pinout
            standard = 0,
            ///The TX and RX pins functions are swapped
            swapped = 1,
        } = .standard,
        ///RXINV [16:16]
        ///RX pin active level
        ///inversion
        rxinv: packed enum(u1) {
            ///RX pin signal works using the standard logic levels
            standard = 0,
            ///RX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///TXINV [17:17]
        ///TX pin active level
        ///inversion
        txinv: packed enum(u1) {
            ///TX pin signal works using the standard logic levels
            standard = 0,
            ///TX pin signal values are inverted
            inverted = 1,
        } = .standard,
        ///DATAINV [18:18]
        ///Binary data inversion
        datainv: packed enum(u1) {
            ///Logical data from the data register are send/received in positive/direct logic
            positive = 0,
            ///Logical data from the data register are send/received in negative/inverse logic
            negative = 1,
        } = .positive,
        ///MSBFIRST [19:19]
        ///Most significant bit first
        msbfirst: packed enum(u1) {
            ///data is transmitted/received with data bit 0 first, following the start bit
            lsb = 0,
            ///data is transmitted/received with MSB (bit 7/8/9) first, following the start bit
            msb = 1,
        } = .lsb,
        ///ABREN [20:20]
        ///Auto baud rate enable
        abren: packed enum(u1) {
            ///Auto baud rate detection is disabled
            disabled = 0,
            ///Auto baud rate detection is enabled
            enabled = 1,
        } = .disabled,
        ///ABRMOD [21:22]
        ///Auto baud rate mode
        abrmod: packed enum(u2) {
            ///Measurement of the start bit is used to detect the baud rate
            start = 0,
            ///Falling edge to falling edge measurement
            edge = 1,
            ///0x7F frame detection
            frame7f = 2,
            ///0x55 frame detection
            frame55 = 3,
        } = .start,
        ///RTOEN [23:23]
        ///Receiver timeout enable
        rtoen: packed enum(u1) {
            ///Receiver timeout feature disabled
            disabled = 0,
            ///Receiver timeout feature enabled
            enabled = 1,
        } = .disabled,
        ///ADD [24:31]
        ///Address of the USART node
        add: u8 = 0,
    };
    ///Control register 2
    pub const cr2 = Register(cr2_val).init(0x40005000 + 0x4);

    //////////////////////////
    ///CR3
    const cr3_val = packed struct {
        ///EIE [0:0]
        ///Error interrupt enable
        eie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated when FE=1 or ORE=1 or NF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///IREN [1:1]
        ///IrDA mode enable
        iren: packed enum(u1) {
            ///IrDA disabled
            disabled = 0,
            ///IrDA enabled
            enabled = 1,
        } = .disabled,
        ///IRLP [2:2]
        ///IrDA low-power
        irlp: packed enum(u1) {
            ///Normal mode
            normal = 0,
            ///Low-power mode
            low_power = 1,
        } = .normal,
        ///HDSEL [3:3]
        ///Half-duplex selection
        hdsel: packed enum(u1) {
            ///Half duplex mode is not selected
            not_selected = 0,
            ///Half duplex mode is selected
            selected = 1,
        } = .not_selected,
        ///NACK [4:4]
        ///Smartcard NACK enable
        nack: packed enum(u1) {
            ///NACK transmission in case of parity error is disabled
            disabled = 0,
            ///NACK transmission during parity error is enabled
            enabled = 1,
        } = .disabled,
        ///SCEN [5:5]
        ///Smartcard mode enable
        scen: packed enum(u1) {
            ///Smartcard Mode disabled
            disabled = 0,
            ///Smartcard Mode enabled
            enabled = 1,
        } = .disabled,
        ///DMAR [6:6]
        ///DMA enable receiver
        dmar: packed enum(u1) {
            ///DMA mode is disabled for reception
            disabled = 0,
            ///DMA mode is enabled for reception
            enabled = 1,
        } = .disabled,
        ///DMAT [7:7]
        ///DMA enable transmitter
        dmat: packed enum(u1) {
            ///DMA mode is disabled for transmission
            disabled = 0,
            ///DMA mode is enabled for transmission
            enabled = 1,
        } = .disabled,
        ///RTSE [8:8]
        ///RTS enable
        rtse: packed enum(u1) {
            ///RTS hardware flow control disabled
            disabled = 0,
            ///RTS output enabled, data is only requested when there is space in the receive buffer
            enabled = 1,
        } = .disabled,
        ///CTSE [9:9]
        ///CTS enable
        ctse: packed enum(u1) {
            ///CTS hardware flow control disabled
            disabled = 0,
            ///CTS mode enabled, data is only transmitted when the CTS input is asserted
            enabled = 1,
        } = .disabled,
        ///CTSIE [10:10]
        ///CTS interrupt enable
        ctsie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An interrupt is generated whenever CTSIF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        ///ONEBIT [11:11]
        ///One sample bit method
        ///enable
        onebit: packed enum(u1) {
            ///Three sample bit method
            sample3 = 0,
            ///One sample bit method
            sample1 = 1,
        } = .sample3,
        ///OVRDIS [12:12]
        ///Overrun Disable
        ovrdis: packed enum(u1) {
            ///Overrun Error Flag, ORE, is set when received data is not read before receiving new data
            enabled = 0,
            ///Overrun functionality is disabled. If new data is received while the RXNE flag is still set the ORE flag is not set and the new received data overwrites the previous content of the RDR register
            disabled = 1,
        } = .enabled,
        ///DDRE [13:13]
        ///DMA Disable on Reception
        ///Error
        ddre: packed enum(u1) {
            ///DMA is not disabled in case of reception error
            not_disabled = 0,
            ///DMA is disabled following a reception error
            disabled = 1,
        } = .not_disabled,
        ///DEM [14:14]
        ///Driver enable mode
        dem: packed enum(u1) {
            ///DE function is disabled
            disabled = 0,
            ///The DE signal is output on the RTS pin
            enabled = 1,
        } = .disabled,
        ///DEP [15:15]
        ///Driver enable polarity
        ///selection
        dep: packed enum(u1) {
            ///DE signal is active high
            high = 0,
            ///DE signal is active low
            low = 1,
        } = .high,
        _unused16: u1 = 0,
        ///SCARCNT [17:19]
        ///Smartcard auto-retry count
        scarcnt: u3 = 0,
        ///WUS [20:21]
        ///Wakeup from Stop mode interrupt flag
        ///selection
        wus: packed enum(u2) {
            ///WUF active on address match
            address = 0,
            ///WuF active on Start bit detection
            start = 2,
            ///WUF active on RXNE
            rxne = 3,
        } = .address,
        ///WUFIE [22:22]
        ///Wakeup from Stop mode interrupt
        ///enable
        wufie: packed enum(u1) {
            ///Interrupt is inhibited
            disabled = 0,
            ///An USART interrupt is generated whenever WUF=1 in the ISR register
            enabled = 1,
        } = .disabled,
        _unused23: u9 = 0,
    };
    ///Control register 3
    pub const cr3 = Register(cr3_val).init(0x40005000 + 0x8);

    //////////////////////////
    ///BRR
    const brr_val = packed struct {
        ///BRR [0:15]
        ///mantissa of USARTDIV
        brr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///Baud rate register
    pub const brr = Register(brr_val).init(0x40005000 + 0xC);

    //////////////////////////
    ///GTPR
    const gtpr_val = packed struct {
        ///PSC [0:7]
        ///Prescaler value
        psc: u8 = 0,
        ///GT [8:15]
        ///Guard time value
        gt: u8 = 0,
        _unused16: u16 = 0,
    };
    ///Guard time and prescaler
    ///register
    pub const gtpr = Register(gtpr_val).init(0x40005000 + 0x10);

    //////////////////////////
    ///RTOR
    const rtor_val = packed struct {
        ///RTO [0:23]
        ///Receiver timeout value
        rto: u24 = 0,
        ///BLEN [24:31]
        ///Block Length
        blen: u8 = 0,
    };
    ///Receiver timeout register
    pub const rtor = Register(rtor_val).init(0x40005000 + 0x14);

    //////////////////////////
    ///RQR
    const rqr_val = packed struct {
        ///ABRRQ [0:0]
        ///Auto baud rate request
        abrrq: packed enum(u1) {
            ///resets the ABRF flag in the USART_ISR and request an automatic baud rate measurement on the next received data frame
            request = 1,
            _zero = 0,
        } = ._zero,
        ///SBKRQ [1:1]
        ///Send break request
        sbkrq: packed enum(u1) {
            ///sets the SBKF flag and request to send a BREAK on the line, as soon as the transmit machine is available
            _break = 1,
            _zero = 0,
        } = ._zero,
        ///MMRQ [2:2]
        ///Mute mode request
        mmrq: packed enum(u1) {
            ///Puts the USART in mute mode and sets the RWU flag
            mute = 1,
            _zero = 0,
        } = ._zero,
        ///RXFRQ [3:3]
        ///Receive data flush request
        rxfrq: packed enum(u1) {
            ///clears the RXNE flag. This allows to discard the received data without reading it, and avoid an overrun condition
            discard = 1,
            _zero = 0,
        } = ._zero,
        ///TXFRQ [4:4]
        ///Transmit data flush
        ///request
        txfrq: packed enum(u1) {
            ///Set the TXE flags. This allows to discard the transmit data
            discard = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u27 = 0,
    };
    ///Request register
    pub const rqr = Register(rqr_val).init(0x40005000 + 0x18);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///PE [0:0]
        ///Parity error
        pe: u1 = 0,
        ///FE [1:1]
        ///Framing error
        fe: u1 = 0,
        ///NF [2:2]
        ///Noise detected flag
        nf: u1 = 0,
        ///ORE [3:3]
        ///Overrun error
        ore: u1 = 0,
        ///IDLE [4:4]
        ///Idle line detected
        idle: u1 = 0,
        ///RXNE [5:5]
        ///Read data register not
        ///empty
        rxne: u1 = 0,
        ///TC [6:6]
        ///Transmission complete
        tc: u1 = 1,
        ///TXE [7:7]
        ///Transmit data register
        ///empty
        txe: u1 = 1,
        ///LBDF [8:8]
        ///LIN break detection flag
        lbdf: u1 = 0,
        ///CTSIF [9:9]
        ///CTS interrupt flag
        ctsif: u1 = 0,
        ///CTS [10:10]
        ///CTS flag
        cts: u1 = 0,
        ///RTOF [11:11]
        ///Receiver timeout
        rtof: u1 = 0,
        ///EOBF [12:12]
        ///End of block flag
        eobf: u1 = 0,
        _unused13: u1 = 0,
        ///ABRE [14:14]
        ///Auto baud rate error
        abre: u1 = 0,
        ///ABRF [15:15]
        ///Auto baud rate flag
        abrf: u1 = 0,
        ///BUSY [16:16]
        ///Busy flag
        busy: u1 = 0,
        ///CMF [17:17]
        ///character match flag
        cmf: u1 = 0,
        ///SBKF [18:18]
        ///Send break flag
        sbkf: u1 = 0,
        ///RWU [19:19]
        ///Receiver wakeup from Mute
        ///mode
        rwu: u1 = 0,
        ///WUF [20:20]
        ///Wakeup from Stop mode flag
        wuf: u1 = 0,
        ///TEACK [21:21]
        ///Transmit enable acknowledge
        ///flag
        teack: u1 = 0,
        ///REACK [22:22]
        ///Receive enable acknowledge
        ///flag
        reack: u1 = 0,
        _unused23: u9 = 0,
    };
    ///Interrupt & status
    ///register
    pub const isr = RegisterRW(isr_val, void).init(0x40005000 + 0x1C);

    //////////////////////////
    ///ICR
    const icr_val = packed struct {
        ///PECF [0:0]
        ///Parity error clear flag
        pecf: packed enum(u1) {
            ///Clears the PE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///FECF [1:1]
        ///Framing error clear flag
        fecf: packed enum(u1) {
            ///Clears the FE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///NCF [2:2]
        ///Noise detected clear flag
        ncf: packed enum(u1) {
            ///Clears the NF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///ORECF [3:3]
        ///Overrun error clear flag
        orecf: packed enum(u1) {
            ///Clears the ORE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///IDLECF [4:4]
        ///Idle line detected clear
        ///flag
        idlecf: packed enum(u1) {
            ///Clears the IDLE flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused5: u1 = 0,
        ///TCCF [6:6]
        ///Transmission complete clear
        ///flag
        tccf: packed enum(u1) {
            ///Clears the TC flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused7: u1 = 0,
        ///LBDCF [8:8]
        ///LIN break detection clear
        ///flag
        lbdcf: packed enum(u1) {
            ///Clears the LBDF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///CTSCF [9:9]
        ///CTS clear flag
        ctscf: packed enum(u1) {
            ///Clears the CTSIF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused10: u1 = 0,
        ///RTOCF [11:11]
        ///Receiver timeout clear
        ///flag
        rtocf: packed enum(u1) {
            ///Clears the RTOF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        ///EOBCF [12:12]
        ///End of timeout clear flag
        eobcf: packed enum(u1) {
            ///Clears the EOBF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused13: u4 = 0,
        ///CMCF [17:17]
        ///Character match clear flag
        cmcf: packed enum(u1) {
            ///Clears the CMF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused18: u2 = 0,
        ///WUCF [20:20]
        ///Wakeup from Stop mode clear
        ///flag
        wucf: packed enum(u1) {
            ///Clears the WUF flag in the ISR register
            clear = 1,
            _zero = 0,
        } = ._zero,
        _unused21: u11 = 0,
    };
    ///Interrupt flag clear register
    pub const icr = Register(icr_val).init(0x40005000 + 0x20);

    //////////////////////////
    ///RDR
    const rdr_val = packed struct {
        ///RDR [0:8]
        ///Receive data value
        rdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Receive data register
    pub const rdr = RegisterRW(rdr_val, void).init(0x40005000 + 0x24);

    //////////////////////////
    ///TDR
    const tdr_val = packed struct {
        ///TDR [0:8]
        ///Transmit data value
        tdr: u9 = 0,
        _unused9: u23 = 0,
    };
    ///Transmit data register
    pub const tdr = Register(tdr_val).init(0x40005000 + 0x28);
};

///Real-time clock
pub const rtc = struct {

    //////////////////////////
    ///TR
    const tr_val = packed struct {
        ///SU [0:3]
        ///Second units in BCD format
        su: u4 = 0,
        ///ST [4:6]
        ///Second tens in BCD format
        st: u3 = 0,
        _unused7: u1 = 0,
        ///MNU [8:11]
        ///Minute units in BCD format
        mnu: u4 = 0,
        ///MNT [12:14]
        ///Minute tens in BCD format
        mnt: u3 = 0,
        _unused15: u1 = 0,
        ///HU [16:19]
        ///Hour units in BCD format
        hu: u4 = 0,
        ///HT [20:21]
        ///Hour tens in BCD format
        ht: u2 = 0,
        ///PM [22:22]
        ///AM/PM notation
        pm: u1 = 0,
        _unused23: u9 = 0,
    };
    ///time register
    pub const tr = Register(tr_val).init(0x40002800 + 0x0);

    //////////////////////////
    ///DR
    const dr_val = packed struct {
        ///DU [0:3]
        ///Date units in BCD format
        du: u4 = 1,
        ///DT [4:5]
        ///Date tens in BCD format
        dt: u2 = 0,
        _unused6: u2 = 0,
        ///MU [8:11]
        ///Month units in BCD format
        mu: u4 = 1,
        ///MT [12:12]
        ///Month tens in BCD format
        mt: u1 = 0,
        ///WDU [13:15]
        ///Week day units
        wdu: u3 = 1,
        ///YU [16:19]
        ///Year units in BCD format
        yu: u4 = 0,
        ///YT [20:23]
        ///Year tens in BCD format
        yt: u4 = 0,
        _unused24: u8 = 0,
    };
    ///date register
    pub const dr = Register(dr_val).init(0x40002800 + 0x4);

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        _unused0: u3 = 0,
        ///TSEDGE [3:3]
        ///Time-stamp event active
        ///edge
        tsedge: u1 = 0,
        ///REFCKON [4:4]
        ///RTC_REFIN reference clock detection
        ///enable (50 or 60 Hz)
        refckon: u1 = 0,
        ///BYPSHAD [5:5]
        ///Bypass the shadow
        ///registers
        bypshad: u1 = 0,
        ///FMT [6:6]
        ///Hour format
        fmt: u1 = 0,
        _unused7: u1 = 0,
        ///ALRAE [8:8]
        ///Alarm A enable
        alrae: u1 = 0,
        _unused9: u2 = 0,
        ///TSE [11:11]
        ///timestamp enable
        tse: u1 = 0,
        ///ALRAIE [12:12]
        ///Alarm A interrupt enable
        alraie: u1 = 0,
        _unused13: u2 = 0,
        ///TSIE [15:15]
        ///Time-stamp interrupt
        ///enable
        tsie: u1 = 0,
        ///ADD1H [16:16]
        ///Add 1 hour (summer time
        ///change)
        add1h: u1 = 0,
        ///SUB1H [17:17]
        ///Subtract 1 hour (winter time
        ///change)
        sub1h: u1 = 0,
        ///BKP [18:18]
        ///Backup
        bkp: u1 = 0,
        ///COSEL [19:19]
        ///Calibration output
        ///selection
        cosel: u1 = 0,
        ///POL [20:20]
        ///Output polarity
        pol: u1 = 0,
        ///OSEL [21:22]
        ///Output selection
        osel: u2 = 0,
        ///COE [23:23]
        ///Calibration output enable
        coe: u1 = 0,
        _unused24: u8 = 0,
    };
    ///control register
    pub const cr = Register(cr_val).init(0x40002800 + 0x8);

    //////////////////////////
    ///ISR
    const isr_val = packed struct {
        ///ALRAWF [0:0]
        ///Alarm A write flag
        alrawf: u1 = 1,
        _unused1: u2 = 0,
        ///SHPF [3:3]
        ///Shift operation pending
        shpf: u1 = 0,
        ///INITS [4:4]
        ///Initialization status flag
        inits: u1 = 0,
        ///RSF [5:5]
        ///Registers synchronization
        ///flag
        rsf: u1 = 0,
        ///INITF [6:6]
        ///Initialization flag
        initf: u1 = 0,
        ///INIT [7:7]
        ///Initialization mode
        init: u1 = 0,
        ///ALRAF [8:8]
        ///Alarm A flag
        alraf: u1 = 0,
        _unused9: u2 = 0,
        ///TSF [11:11]
        ///Time-stamp flag
        tsf: u1 = 0,
        ///TSOVF [12:12]
        ///Time-stamp overflow flag
        tsovf: u1 = 0,
        ///TAMP1F [13:13]
        ///RTC_TAMP1 detection flag
        tamp1f: u1 = 0,
        ///TAMP2F [14:14]
        ///RTC_TAMP2 detection flag
        tamp2f: u1 = 0,
        _unused15: u1 = 0,
        ///RECALPF [16:16]
        ///Recalibration pending Flag
        recalpf: u1 = 0,
        _unused17: u15 = 0,
    };
    ///initialization and status
    ///register
    pub const isr = Register(isr_val).init(0x40002800 + 0xC);

    //////////////////////////
    ///PRER
    const prer_val = packed struct {
        ///PREDIV_S [0:14]
        ///Synchronous prescaler
        ///factor
        prediv_s: u15 = 255,
        _unused15: u1 = 0,
        ///PREDIV_A [16:22]
        ///Asynchronous prescaler
        ///factor
        prediv_a: u7 = 127,
        _unused23: u9 = 0,
    };
    ///prescaler register
    pub const prer = Register(prer_val).init(0x40002800 + 0x10);

    //////////////////////////
    ///ALRMAR
    const alrmar_val = packed struct {
        ///SU [0:3]
        ///Second units in BCD
        ///format.
        su: u4 = 0,
        ///ST [4:6]
        ///Second tens in BCD format.
        st: u3 = 0,
        ///MSK1 [7:7]
        ///Alarm A seconds mask
        msk1: u1 = 0,
        ///MNU [8:11]
        ///Minute units in BCD
        ///format.
        mnu: u4 = 0,
        ///MNT [12:14]
        ///Minute tens in BCD format.
        mnt: u3 = 0,
        ///MSK2 [15:15]
        ///Alarm A minutes mask
        msk2: u1 = 0,
        ///HU [16:19]
        ///Hour units in BCD format.
        hu: u4 = 0,
        ///HT [20:21]
        ///Hour tens in BCD format.
        ht: u2 = 0,
        ///PM [22:22]
        ///AM/PM notation
        pm: u1 = 0,
        ///MSK3 [23:23]
        ///Alarm A hours mask
        msk3: u1 = 0,
        ///DU [24:27]
        ///Date units or day in BCD
        ///format.
        du: u4 = 0,
        ///DT [28:29]
        ///Date tens in BCD format.
        dt: u2 = 0,
        ///WDSEL [30:30]
        ///Week day selection
        wdsel: u1 = 0,
        ///MSK4 [31:31]
        ///Alarm A date mask
        msk4: u1 = 0,
    };
    ///alarm A register
    pub const alrmar = Register(alrmar_val).init(0x40002800 + 0x1C);

    //////////////////////////
    ///WPR
    const wpr_val = packed struct {
        ///KEY [0:7]
        ///Write protection key
        key: u8 = 0,
        _unused8: u24 = 0,
    };
    ///write protection register
    pub const wpr = RegisterRW(void, wpr_val).init(0x40002800 + 0x24);

    //////////////////////////
    ///SSR
    const ssr_val = packed struct {
        ///SS [0:15]
        ///Sub second value
        ss: u16 = 0,
        _unused16: u16 = 0,
    };
    ///sub second register
    pub const ssr = RegisterRW(ssr_val, void).init(0x40002800 + 0x28);

    //////////////////////////
    ///SHIFTR
    const shiftr_val = packed struct {
        ///SUBFS [0:14]
        ///Subtract a fraction of a
        ///second
        subfs: u15 = 0,
        _unused15: u16 = 0,
        ///ADD1S [31:31]
        ///Add one second
        add1s: u1 = 0,
    };
    ///shift control register
    pub const shiftr = RegisterRW(void, shiftr_val).init(0x40002800 + 0x2C);

    //////////////////////////
    ///TSTR
    const tstr_val = packed struct {
        ///SU [0:3]
        ///Second units in BCD
        ///format.
        su: u4 = 0,
        ///ST [4:6]
        ///Second tens in BCD format.
        st: u3 = 0,
        _unused7: u1 = 0,
        ///MNU [8:11]
        ///Minute units in BCD
        ///format.
        mnu: u4 = 0,
        ///MNT [12:14]
        ///Minute tens in BCD format.
        mnt: u3 = 0,
        _unused15: u1 = 0,
        ///HU [16:19]
        ///Hour units in BCD format.
        hu: u4 = 0,
        ///HT [20:21]
        ///Hour tens in BCD format.
        ht: u2 = 0,
        ///PM [22:22]
        ///AM/PM notation
        pm: u1 = 0,
        _unused23: u9 = 0,
    };
    ///timestamp time register
    pub const tstr = RegisterRW(tstr_val, void).init(0x40002800 + 0x30);

    //////////////////////////
    ///TSDR
    const tsdr_val = packed struct {
        ///DU [0:3]
        ///Date units in BCD format
        du: u4 = 0,
        ///DT [4:5]
        ///Date tens in BCD format
        dt: u2 = 0,
        _unused6: u2 = 0,
        ///MU [8:11]
        ///Month units in BCD format
        mu: u4 = 0,
        ///MT [12:12]
        ///Month tens in BCD format
        mt: u1 = 0,
        ///WDU [13:15]
        ///Week day units
        wdu: u3 = 0,
        _unused16: u16 = 0,
    };
    ///timestamp date register
    pub const tsdr = RegisterRW(tsdr_val, void).init(0x40002800 + 0x34);

    //////////////////////////
    ///TSSSR
    const tsssr_val = packed struct {
        ///SS [0:15]
        ///Sub second value
        ss: u16 = 0,
        _unused16: u16 = 0,
    };
    ///time-stamp sub second register
    pub const tsssr = RegisterRW(tsssr_val, void).init(0x40002800 + 0x38);

    //////////////////////////
    ///CALR
    const calr_val = packed struct {
        ///CALM [0:8]
        ///Calibration minus
        calm: u9 = 0,
        _unused9: u4 = 0,
        ///CALW16 [13:13]
        ///Use a 16-second calibration cycle
        ///period
        calw16: u1 = 0,
        ///CALW8 [14:14]
        ///Use a 16-second calibration cycle
        ///period
        calw8: u1 = 0,
        ///CALP [15:15]
        ///Use an 8-second calibration cycle
        ///period
        calp: u1 = 0,
        _unused16: u16 = 0,
    };
    ///calibration register
    pub const calr = Register(calr_val).init(0x40002800 + 0x3C);

    //////////////////////////
    ///TAFCR
    const tafcr_val = packed struct {
        ///TAMP1E [0:0]
        ///RTC_TAMP1 input detection
        ///enable
        tamp1e: u1 = 0,
        ///TAMP1TRG [1:1]
        ///Active level for RTC_TAMP1
        ///input
        tamp1trg: u1 = 0,
        ///TAMPIE [2:2]
        ///Tamper interrupt enable
        tampie: u1 = 0,
        ///TAMP2E [3:3]
        ///RTC_TAMP2 input detection
        ///enable
        tamp2e: u1 = 0,
        ///TAMP2_TRG [4:4]
        ///Active level for RTC_TAMP2
        ///input
        tamp2_trg: u1 = 0,
        _unused5: u2 = 0,
        ///TAMPTS [7:7]
        ///Activate timestamp on tamper detection
        ///event
        tampts: u1 = 0,
        ///TAMPFREQ [8:10]
        ///Tamper sampling frequency
        tampfreq: u3 = 0,
        ///TAMPFLT [11:12]
        ///RTC_TAMPx filter count
        tampflt: u2 = 0,
        ///TAMP_PRCH [13:14]
        ///RTC_TAMPx precharge
        ///duration
        tamp_prch: u2 = 0,
        ///TAMP_PUDIS [15:15]
        ///RTC_TAMPx pull-up disable
        tamp_pudis: u1 = 0,
        _unused16: u2 = 0,
        ///PC13VALUE [18:18]
        ///RTC_ALARM output type/PC13
        ///value
        pc13value: u1 = 0,
        ///PC13MODE [19:19]
        ///PC13 mode
        pc13mode: u1 = 0,
        ///PC14VALUE [20:20]
        ///PC14 value
        pc14value: u1 = 0,
        ///PC14MODE [21:21]
        ///PC14 mode
        pc14mode: u1 = 0,
        ///PC15VALUE [22:22]
        ///PC15 value
        pc15value: u1 = 0,
        ///PC15MODE [23:23]
        ///PC15 mode
        pc15mode: u1 = 0,
        _unused24: u8 = 0,
    };
    ///tamper and alternate function configuration
    ///register
    pub const tafcr = Register(tafcr_val).init(0x40002800 + 0x40);

    //////////////////////////
    ///ALRMASSR
    const alrmassr_val = packed struct {
        ///SS [0:14]
        ///Sub seconds value
        ss: u15 = 0,
        _unused15: u9 = 0,
        ///MASKSS [24:27]
        ///Mask the most-significant bits starting
        ///at this bit
        maskss: u4 = 0,
        _unused28: u4 = 0,
    };
    ///alarm A sub second register
    pub const alrmassr = Register(alrmassr_val).init(0x40002800 + 0x44);

    //////////////////////////
    ///BKP%sR
    const bkpr_val = packed struct {
        ///BKP [0:31]
        ///BKP
        bkp: u32 = 0,
    };
    ///backup register
    pub const bkpr = Register(bkpr_val).initRange(0x40002800 + 0x50, 4, 5);
};

///General-purpose-timers
pub const tim15 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: u1 = 0,
        _unused4: u3 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40014000 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///CCPC [0:0]
        ///Capture/compare preloaded
        ///control
        ccpc: u1 = 0,
        _unused1: u1 = 0,
        ///CCUS [2:2]
        ///Capture/compare control update
        ///selection
        ccus: u1 = 0,
        ///CCDS [3:3]
        ///Capture/compare DMA
        ///selection
        ccds: u1 = 0,
        ///MMS [4:6]
        ///Master mode selection
        mms: u3 = 0,
        _unused7: u1 = 0,
        ///OIS1 [8:8]
        ///Output Idle state 1
        ois1: u1 = 0,
        ///OIS1N [9:9]
        ///Output Idle state 1
        ois1n: u1 = 0,
        ///OIS2 [10:10]
        ///Output Idle state 2
        ois2: u1 = 0,
        _unused11: u21 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40014000 + 0x4);

    //////////////////////////
    ///SMCR
    const smcr_val = packed struct {
        ///SMS [0:2]
        ///Slave mode selection
        sms: u3 = 0,
        _unused3: u1 = 0,
        ///TS [4:6]
        ///Trigger selection
        ts: u3 = 0,
        ///MSM [7:7]
        ///Master/Slave mode
        msm: u1 = 0,
        _unused8: u24 = 0,
    };
    ///slave mode control register
    pub const smcr = Register(smcr_val).init(0x40014000 + 0x8);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: u1 = 0,
        ///CC2IE [2:2]
        ///Capture/Compare 2 interrupt
        ///enable
        cc2ie: u1 = 0,
        _unused3: u2 = 0,
        ///COMIE [5:5]
        ///COM interrupt enable
        comie: u1 = 0,
        ///TIE [6:6]
        ///Trigger interrupt enable
        tie: u1 = 0,
        ///BIE [7:7]
        ///Break interrupt enable
        bie: u1 = 0,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: u1 = 0,
        ///CC1DE [9:9]
        ///Capture/Compare 1 DMA request
        ///enable
        cc1de: u1 = 0,
        ///CC2DE [10:10]
        ///Capture/Compare 2 DMA request
        ///enable
        cc2de: u1 = 0,
        _unused11: u3 = 0,
        ///TDE [14:14]
        ///Trigger DMA request enable
        tde: u1 = 0,
        _unused15: u17 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40014000 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        ///CC2IF [2:2]
        ///Capture/Compare 2 interrupt
        ///flag
        cc2if: u1 = 0,
        _unused3: u2 = 0,
        ///COMIF [5:5]
        ///COM interrupt flag
        comif: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: u1 = 0,
        ///BIF [7:7]
        ///Break interrupt flag
        bif: u1 = 0,
        _unused8: u1 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        ///CC2OF [10:10]
        ///Capture/compare 2 overcapture
        ///flag
        cc2of: u1 = 0,
        _unused11: u21 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40014000 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        ///CC2G [2:2]
        ///Capture/compare 2
        ///generation
        cc2g: u1 = 0,
        _unused3: u2 = 0,
        ///COMG [5:5]
        ///Capture/Compare control update
        ///generation
        comg: u1 = 0,
        ///TG [6:6]
        ///Trigger generation
        tg: u1 = 0,
        ///BG [7:7]
        ///Break generation
        bg: u1 = 0,
        _unused8: u24 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40014000 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///OC1FE [2:2]
        ///Output Compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output Compare 1 preload
        ///enable
        oc1pe: u1 = 0,
        ///OC1M [4:6]
        ///Output Compare 1 mode
        oc1m: u3 = 0,
        _unused7: u1 = 0,
        ///CC2S [8:9]
        ///Capture/Compare 2
        ///selection
        cc2s: u2 = 0,
        ///OC2FE [10:10]
        ///Output Compare 2 fast
        ///enable
        oc2fe: u1 = 0,
        ///OC2PE [11:11]
        ///Output Compare 2 preload
        ///enable
        oc2pe: u1 = 0,
        ///OC2M [12:14]
        ///Output Compare 2 mode
        oc2m: u3 = 0,
        _unused15: u17 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40014000 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: u4 = 0,
        ///CC2S [8:9]
        ///Capture/Compare 2
        ///selection
        cc2s: u2 = 0,
        ///IC2PSC [10:11]
        ///Input capture 2 prescaler
        ic2psc: u2 = 0,
        ///IC2F [12:15]
        ///Input capture 2 filter
        ic2f: u4 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare mode register 1 (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40014000 + 0x18);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        ///CC1NE [2:2]
        ///Capture/Compare 1 complementary output
        ///enable
        cc1ne: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        ///CC2E [4:4]
        ///Capture/Compare 2 output
        ///enable
        cc2e: u1 = 0,
        ///CC2P [5:5]
        ///Capture/Compare 2 output
        ///Polarity
        cc2p: u1 = 0,
        _unused6: u1 = 0,
        ///CC2NP [7:7]
        ///Capture/Compare 2 output
        ///Polarity
        cc2np: u1 = 0,
        _unused8: u24 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40014000 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40014000 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40014000 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40014000 + 0x2C);

    //////////////////////////
    ///RCR
    const rcr_val = packed struct {
        ///REP [0:7]
        ///Repetition counter value
        rep: u8 = 0,
        _unused8: u24 = 0,
    };
    ///repetition counter register
    pub const rcr = Register(rcr_val).init(0x40014000 + 0x30);

    //////////////////////////
    ///CCR1
    const ccr1_val = packed struct {
        ///CCR1 [0:15]
        ///Capture/Compare 1 value
        ccr1: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr1 = Register(ccr1_val).init(0x40014000 + 0x34);

    //////////////////////////
    ///CCR2
    const ccr2_val = packed struct {
        ///CCR2 [0:15]
        ///Capture/Compare 2 value
        ccr2: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 2
    pub const ccr2 = Register(ccr2_val).init(0x40014000 + 0x38);

    //////////////////////////
    ///BDTR
    const bdtr_val = packed struct {
        ///DTG [0:7]
        ///Dead-time generator setup
        dtg: u8 = 0,
        ///LOCK [8:9]
        ///Lock configuration
        lock: u2 = 0,
        ///OSSI [10:10]
        ///Off-state selection for Idle
        ///mode
        ossi: u1 = 0,
        ///OSSR [11:11]
        ///Off-state selection for Run
        ///mode
        ossr: u1 = 0,
        ///BKE [12:12]
        ///Break enable
        bke: u1 = 0,
        ///BKP [13:13]
        ///Break polarity
        bkp: u1 = 0,
        ///AOE [14:14]
        ///Automatic output enable
        aoe: u1 = 0,
        ///MOE [15:15]
        ///Main output enable
        moe: u1 = 0,
        _unused16: u16 = 0,
    };
    ///break and dead-time register
    pub const bdtr = Register(bdtr_val).init(0x40014000 + 0x44);

    //////////////////////////
    ///DCR
    const dcr_val = packed struct {
        ///DBA [0:4]
        ///DMA base address
        dba: u5 = 0,
        _unused5: u3 = 0,
        ///DBL [8:12]
        ///DMA burst length
        dbl: u5 = 0,
        _unused13: u19 = 0,
    };
    ///DMA control register
    pub const dcr = Register(dcr_val).init(0x40014000 + 0x48);

    //////////////////////////
    ///DMAR
    const dmar_val = packed struct {
        ///DMAB [0:15]
        ///DMA register for burst
        ///accesses
        dmab: u16 = 0,
        _unused16: u16 = 0,
    };
    ///DMA address for full transfer
    pub const dmar = Register(dmar_val).init(0x40014000 + 0x4C);
};

///General-purpose-timers
pub const tim16 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Not stopped at update event
            not_stopped = 0,
            ///Counter stops counting at next update event
            stopped = 1,
        } = .not_stopped,
        _unused4: u3 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40014400 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///CCPC [0:0]
        ///Capture/compare preloaded
        ///control
        ccpc: packed enum(u1) {
            ///CCxE, CCxNE and OCxM bits are not preloaded
            not_preloaded = 0,
            ///CCxE, CCxNE and OCxM bits are preloaded
            preloaded = 1,
        } = .not_preloaded,
        _unused1: u1 = 0,
        ///CCUS [2:2]
        ///Capture/compare control update
        ///selection
        ccus: packed enum(u1) {
            ///Capture/compare are updated only by setting the COMG bit
            default = 0,
            ///Capture/compare are updated by setting the COMG bit or when an rising edge occurs on TRGI
            with_rising_edge = 1,
        } = .default,
        ///CCDS [3:3]
        ///Capture/compare DMA
        ///selection
        ccds: packed enum(u1) {
            ///CCx DMA request sent when CCx event occurs
            on_compare = 0,
            ///CCx DMA request sent when update event occurs
            on_update = 1,
        } = .on_compare,
        _unused4: u4 = 0,
        ///OIS1 [8:8]
        ///Output Idle state 1
        ois1: packed enum(u1) {
            ///OC1=0 (after a dead-time if OC1N is implemented) when MOE=0
            low = 0,
            ///OC1=1 (after a dead-time if OC1N is implemented) when MOE=0
            high = 1,
        } = .low,
        ///OIS1N [9:9]
        ///Output Idle state 1
        ois1n: packed enum(u1) {
            ///OC1N=0 after a dead-time when MOE=0
            low = 0,
            ///OC1N=1 after a dead-time when MOE=0
            high = 1,
        } = .low,
        _unused10: u22 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40014400 + 0x4);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: packed enum(u1) {
            ///CC1 interrupt disabled
            disabled = 0,
            ///CC1 interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused2: u3 = 0,
        ///COMIE [5:5]
        ///COM interrupt enable
        comie: packed enum(u1) {
            ///COM interrupt disabled
            disabled = 0,
            ///COM interrupt enabled
            enabled = 1,
        } = .disabled,
        ///TIE [6:6]
        ///Trigger interrupt enable
        tie: u1 = 0,
        ///BIE [7:7]
        ///Break interrupt enable
        bie: packed enum(u1) {
            ///Break interrupt disabled
            disabled = 0,
            ///Break interrupt enabled
            enabled = 1,
        } = .disabled,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: u1 = 0,
        ///CC1DE [9:9]
        ///Capture/Compare 1 DMA request
        ///enable
        cc1de: packed enum(u1) {
            ///CC1 DMA request disabled
            disabled = 0,
            ///CC1 DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused10: u4 = 0,
        ///TDE [14:14]
        ///Trigger DMA request enable
        tde: u1 = 0,
        _unused15: u17 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40014400 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        _unused2: u3 = 0,
        ///COMIF [5:5]
        ///COM interrupt flag
        comif: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: u1 = 0,
        ///BIF [7:7]
        ///Break interrupt flag
        bif: u1 = 0,
        _unused8: u1 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        _unused10: u22 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40014400 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        _unused2: u3 = 0,
        ///COMG [5:5]
        ///Capture/Compare control update
        ///generation
        comg: u1 = 0,
        ///TG [6:6]
        ///Trigger generation
        tg: u1 = 0,
        ///BG [7:7]
        ///Break generation
        bg: u1 = 0,
        _unused8: u24 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40014400 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///OC1FE [2:2]
        ///Output Compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output Compare 1 preload
        ///enable
        oc1pe: u1 = 0,
        ///OC1M [4:6]
        ///Output Compare 1 mode
        oc1m: u3 = 0,
        _unused7: u25 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40014400 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: u4 = 0,
        _unused8: u24 = 0,
    };
    ///capture/compare mode register 1 (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40014400 + 0x18);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        ///CC1NE [2:2]
        ///Capture/Compare 1 complementary output
        ///enable
        cc1ne: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        _unused4: u28 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40014400 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40014400 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40014400 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40014400 + 0x2C);

    //////////////////////////
    ///RCR
    const rcr_val = packed struct {
        ///REP [0:7]
        ///Repetition counter value
        rep: u8 = 0,
        _unused8: u24 = 0,
    };
    ///repetition counter register
    pub const rcr = Register(rcr_val).init(0x40014400 + 0x30);

    //////////////////////////
    ///CCR1
    const ccr1_val = packed struct {
        ///CCR1 [0:15]
        ///Capture/Compare 1 value
        ccr1: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr1 = Register(ccr1_val).init(0x40014400 + 0x34);

    //////////////////////////
    ///BDTR
    const bdtr_val = packed struct {
        ///DTG [0:7]
        ///Dead-time generator setup
        dtg: u8 = 0,
        ///LOCK [8:9]
        ///Lock configuration
        lock: u2 = 0,
        ///OSSI [10:10]
        ///Off-state selection for Idle
        ///mode
        ossi: u1 = 0,
        ///OSSR [11:11]
        ///Off-state selection for Run
        ///mode
        ossr: u1 = 0,
        ///BKE [12:12]
        ///Break enable
        bke: u1 = 0,
        ///BKP [13:13]
        ///Break polarity
        bkp: u1 = 0,
        ///AOE [14:14]
        ///Automatic output enable
        aoe: u1 = 0,
        ///MOE [15:15]
        ///Main output enable
        moe: u1 = 0,
        _unused16: u16 = 0,
    };
    ///break and dead-time register
    pub const bdtr = Register(bdtr_val).init(0x40014400 + 0x44);

    //////////////////////////
    ///DCR
    const dcr_val = packed struct {
        ///DBA [0:4]
        ///DMA base address
        dba: u5 = 0,
        _unused5: u3 = 0,
        ///DBL [8:12]
        ///DMA burst length
        dbl: u5 = 0,
        _unused13: u19 = 0,
    };
    ///DMA control register
    pub const dcr = Register(dcr_val).init(0x40014400 + 0x48);

    //////////////////////////
    ///DMAR
    const dmar_val = packed struct {
        ///DMAB [0:15]
        ///DMA register for burst
        ///accesses
        dmab: u16 = 0,
        _unused16: u16 = 0,
    };
    ///DMA address for full transfer
    pub const dmar = Register(dmar_val).init(0x40014400 + 0x4C);
};

///General-purpose-timers
pub const tim17 = struct {

    //////////////////////////
    ///CR1
    const cr1_val = packed struct {
        ///CEN [0:0]
        ///Counter enable
        cen: packed enum(u1) {
            ///Counter disabled
            disabled = 0,
            ///Counter enabled
            enabled = 1,
        } = .disabled,
        ///UDIS [1:1]
        ///Update disable
        udis: packed enum(u1) {
            ///Update event enabled
            enabled = 0,
            ///Update event disabled
            disabled = 1,
        } = .enabled,
        ///URS [2:2]
        ///Update request source
        urs: packed enum(u1) {
            ///Any of counter overflow/underflow, setting UG, or update through slave mode, generates an update interrupt or DMA request
            any_event = 0,
            ///Only counter overflow/underflow generates an update interrupt or DMA request
            counter_only = 1,
        } = .any_event,
        ///OPM [3:3]
        ///One-pulse mode
        opm: packed enum(u1) {
            ///Not stopped at update event
            not_stopped = 0,
            ///Counter stops counting at next update event
            stopped = 1,
        } = .not_stopped,
        _unused4: u3 = 0,
        ///ARPE [7:7]
        ///Auto-reload preload enable
        arpe: packed enum(u1) {
            ///TIMx_APRR register is not buffered
            disabled = 0,
            ///TIMx_APRR register is buffered
            enabled = 1,
        } = .disabled,
        ///CKD [8:9]
        ///Clock division
        ckd: packed enum(u2) {
            ///t_DTS = t_CK_INT
            div1 = 0,
            ///t_DTS = 2 × t_CK_INT
            div2 = 1,
            ///t_DTS = 4 × t_CK_INT
            div4 = 2,
        } = .div1,
        _unused10: u22 = 0,
    };
    ///control register 1
    pub const cr1 = Register(cr1_val).init(0x40014800 + 0x0);

    //////////////////////////
    ///CR2
    const cr2_val = packed struct {
        ///CCPC [0:0]
        ///Capture/compare preloaded
        ///control
        ccpc: packed enum(u1) {
            ///CCxE, CCxNE and OCxM bits are not preloaded
            not_preloaded = 0,
            ///CCxE, CCxNE and OCxM bits are preloaded
            preloaded = 1,
        } = .not_preloaded,
        _unused1: u1 = 0,
        ///CCUS [2:2]
        ///Capture/compare control update
        ///selection
        ccus: packed enum(u1) {
            ///Capture/compare are updated only by setting the COMG bit
            default = 0,
            ///Capture/compare are updated by setting the COMG bit or when an rising edge occurs on TRGI
            with_rising_edge = 1,
        } = .default,
        ///CCDS [3:3]
        ///Capture/compare DMA
        ///selection
        ccds: packed enum(u1) {
            ///CCx DMA request sent when CCx event occurs
            on_compare = 0,
            ///CCx DMA request sent when update event occurs
            on_update = 1,
        } = .on_compare,
        _unused4: u4 = 0,
        ///OIS1 [8:8]
        ///Output Idle state 1
        ois1: packed enum(u1) {
            ///OC1=0 (after a dead-time if OC1N is implemented) when MOE=0
            low = 0,
            ///OC1=1 (after a dead-time if OC1N is implemented) when MOE=0
            high = 1,
        } = .low,
        ///OIS1N [9:9]
        ///Output Idle state 1
        ois1n: packed enum(u1) {
            ///OC1N=0 after a dead-time when MOE=0
            low = 0,
            ///OC1N=1 after a dead-time when MOE=0
            high = 1,
        } = .low,
        _unused10: u22 = 0,
    };
    ///control register 2
    pub const cr2 = Register(cr2_val).init(0x40014800 + 0x4);

    //////////////////////////
    ///DIER
    const dier_val = packed struct {
        ///UIE [0:0]
        ///Update interrupt enable
        uie: packed enum(u1) {
            ///Update interrupt disabled
            disabled = 0,
            ///Update interrupt enabled
            enabled = 1,
        } = .disabled,
        ///CC1IE [1:1]
        ///Capture/Compare 1 interrupt
        ///enable
        cc1ie: packed enum(u1) {
            ///CC1 interrupt disabled
            disabled = 0,
            ///CC1 interrupt enabled
            enabled = 1,
        } = .disabled,
        _unused2: u3 = 0,
        ///COMIE [5:5]
        ///COM interrupt enable
        comie: packed enum(u1) {
            ///COM interrupt disabled
            disabled = 0,
            ///COM interrupt enabled
            enabled = 1,
        } = .disabled,
        ///TIE [6:6]
        ///Trigger interrupt enable
        tie: u1 = 0,
        ///BIE [7:7]
        ///Break interrupt enable
        bie: packed enum(u1) {
            ///Break interrupt disabled
            disabled = 0,
            ///Break interrupt enabled
            enabled = 1,
        } = .disabled,
        ///UDE [8:8]
        ///Update DMA request enable
        ude: u1 = 0,
        ///CC1DE [9:9]
        ///Capture/Compare 1 DMA request
        ///enable
        cc1de: packed enum(u1) {
            ///CC1 DMA request disabled
            disabled = 0,
            ///CC1 DMA request enabled
            enabled = 1,
        } = .disabled,
        _unused10: u4 = 0,
        ///TDE [14:14]
        ///Trigger DMA request enable
        tde: u1 = 0,
        _unused15: u17 = 0,
    };
    ///DMA/Interrupt enable register
    pub const dier = Register(dier_val).init(0x40014800 + 0xC);

    //////////////////////////
    ///SR
    const sr_val = packed struct {
        ///UIF [0:0]
        ///Update interrupt flag
        uif: packed enum(u1) {
            ///No update occurred
            clear = 0,
            ///Update interrupt pending.
            update_pending = 1,
        } = .clear,
        ///CC1IF [1:1]
        ///Capture/compare 1 interrupt
        ///flag
        cc1if: u1 = 0,
        _unused2: u3 = 0,
        ///COMIF [5:5]
        ///COM interrupt flag
        comif: u1 = 0,
        ///TIF [6:6]
        ///Trigger interrupt flag
        tif: u1 = 0,
        ///BIF [7:7]
        ///Break interrupt flag
        bif: u1 = 0,
        _unused8: u1 = 0,
        ///CC1OF [9:9]
        ///Capture/Compare 1 overcapture
        ///flag
        cc1of: u1 = 0,
        _unused10: u22 = 0,
    };
    ///status register
    pub const sr = Register(sr_val).init(0x40014800 + 0x10);

    //////////////////////////
    ///EGR
    const egr_val = packed struct {
        ///UG [0:0]
        ///Update generation
        ug: packed enum(u1) {
            ///Re-initializes the timer counter and generates an update of the registers.
            update = 1,
            _zero = 0,
        } = ._zero,
        ///CC1G [1:1]
        ///Capture/compare 1
        ///generation
        cc1g: u1 = 0,
        _unused2: u3 = 0,
        ///COMG [5:5]
        ///Capture/Compare control update
        ///generation
        comg: u1 = 0,
        ///TG [6:6]
        ///Trigger generation
        tg: u1 = 0,
        ///BG [7:7]
        ///Break generation
        bg: u1 = 0,
        _unused8: u24 = 0,
    };
    ///event generation register
    pub const egr = RegisterRW(void, egr_val).init(0x40014800 + 0x14);

    //////////////////////////
    ///CCMR1_Output
    const ccmr1_output_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///OC1FE [2:2]
        ///Output Compare 1 fast
        ///enable
        oc1fe: u1 = 0,
        ///OC1PE [3:3]
        ///Output Compare 1 preload
        ///enable
        oc1pe: u1 = 0,
        ///OC1M [4:6]
        ///Output Compare 1 mode
        oc1m: u3 = 0,
        _unused7: u25 = 0,
    };
    ///capture/compare mode register (output
    ///mode)
    pub const ccmr1_output = Register(ccmr1_output_val).init(0x40014800 + 0x18);

    //////////////////////////
    ///CCMR1_Input
    const ccmr1_input_val = packed struct {
        ///CC1S [0:1]
        ///Capture/Compare 1
        ///selection
        cc1s: u2 = 0,
        ///IC1PSC [2:3]
        ///Input capture 1 prescaler
        ic1psc: u2 = 0,
        ///IC1F [4:7]
        ///Input capture 1 filter
        ic1f: u4 = 0,
        _unused8: u24 = 0,
    };
    ///capture/compare mode register 1 (input
    ///mode)
    pub const ccmr1_input = Register(ccmr1_input_val).init(0x40014800 + 0x18);

    //////////////////////////
    ///CCER
    const ccer_val = packed struct {
        ///CC1E [0:0]
        ///Capture/Compare 1 output
        ///enable
        cc1e: u1 = 0,
        ///CC1P [1:1]
        ///Capture/Compare 1 output
        ///Polarity
        cc1p: u1 = 0,
        ///CC1NE [2:2]
        ///Capture/Compare 1 complementary output
        ///enable
        cc1ne: u1 = 0,
        ///CC1NP [3:3]
        ///Capture/Compare 1 output
        ///Polarity
        cc1np: u1 = 0,
        _unused4: u28 = 0,
    };
    ///capture/compare enable
    ///register
    pub const ccer = Register(ccer_val).init(0x40014800 + 0x20);

    //////////////////////////
    ///CNT
    const cnt_val = packed struct {
        ///CNT [0:15]
        ///counter value
        cnt: u16 = 0,
        _unused16: u16 = 0,
    };
    ///counter
    pub const cnt = Register(cnt_val).init(0x40014800 + 0x24);

    //////////////////////////
    ///PSC
    const psc_val = packed struct {
        ///PSC [0:15]
        ///Prescaler value
        psc: u16 = 0,
        _unused16: u16 = 0,
    };
    ///prescaler
    pub const psc = Register(psc_val).init(0x40014800 + 0x28);

    //////////////////////////
    ///ARR
    const arr_val = packed struct {
        ///ARR [0:15]
        ///Auto-reload value
        arr: u16 = 0,
        _unused16: u16 = 0,
    };
    ///auto-reload register
    pub const arr = Register(arr_val).init(0x40014800 + 0x2C);

    //////////////////////////
    ///RCR
    const rcr_val = packed struct {
        ///REP [0:7]
        ///Repetition counter value
        rep: u8 = 0,
        _unused8: u24 = 0,
    };
    ///repetition counter register
    pub const rcr = Register(rcr_val).init(0x40014800 + 0x30);

    //////////////////////////
    ///CCR1
    const ccr1_val = packed struct {
        ///CCR1 [0:15]
        ///Capture/Compare 1 value
        ccr1: u16 = 0,
        _unused16: u16 = 0,
    };
    ///capture/compare register 1
    pub const ccr1 = Register(ccr1_val).init(0x40014800 + 0x34);

    //////////////////////////
    ///BDTR
    const bdtr_val = packed struct {
        ///DTG [0:7]
        ///Dead-time generator setup
        dtg: u8 = 0,
        ///LOCK [8:9]
        ///Lock configuration
        lock: u2 = 0,
        ///OSSI [10:10]
        ///Off-state selection for Idle
        ///mode
        ossi: u1 = 0,
        ///OSSR [11:11]
        ///Off-state selection for Run
        ///mode
        ossr: u1 = 0,
        ///BKE [12:12]
        ///Break enable
        bke: u1 = 0,
        ///BKP [13:13]
        ///Break polarity
        bkp: u1 = 0,
        ///AOE [14:14]
        ///Automatic output enable
        aoe: u1 = 0,
        ///MOE [15:15]
        ///Main output enable
        moe: u1 = 0,
        _unused16: u16 = 0,
    };
    ///break and dead-time register
    pub const bdtr = Register(bdtr_val).init(0x40014800 + 0x44);

    //////////////////////////
    ///DCR
    const dcr_val = packed struct {
        ///DBA [0:4]
        ///DMA base address
        dba: u5 = 0,
        _unused5: u3 = 0,
        ///DBL [8:12]
        ///DMA burst length
        dbl: u5 = 0,
        _unused13: u19 = 0,
    };
    ///DMA control register
    pub const dcr = Register(dcr_val).init(0x40014800 + 0x48);

    //////////////////////////
    ///DMAR
    const dmar_val = packed struct {
        ///DMAB [0:15]
        ///DMA register for burst
        ///accesses
        dmab: u16 = 0,
        _unused16: u16 = 0,
    };
    ///DMA address for full transfer
    pub const dmar = Register(dmar_val).init(0x40014800 + 0x4C);
};

///Flash
pub const flash = struct {

    //////////////////////////
    ///ACR
    const acr_val_read = packed struct {
        ///LATENCY [0:2]
        ///LATENCY
        latency: u3 = 0,
        _unused3: u1 = 0,
        ///PRFTBE [4:4]
        ///PRFTBE
        prftbe: u1 = 1,
        ///PRFTBS [5:5]
        ///PRFTBS
        prftbs: packed enum(u1) {
            ///Prefetch buffer is disabled
            disabled = 0,
            ///Prefetch buffer is enabled
            enabled = 1,
        } = .enabled,
        _unused6: u26 = 0,
    };
    const acr_val_write = packed struct {
        ///LATENCY [0:2]
        ///LATENCY
        latency: u3 = 0,
        _unused3: u1 = 0,
        ///PRFTBE [4:4]
        ///PRFTBE
        prftbe: u1 = 1,
        ///PRFTBS [5:5]
        ///PRFTBS
        prftbs: u1 = 1,
        _unused6: u26 = 0,
    };
    ///Flash access control register
    pub const acr = Register(acr_val).init(0x40022000 + 0x0);

    //////////////////////////
    ///KEYR
    const keyr_val = packed struct {
        ///FKEYR [0:31]
        ///Flash Key
        fkeyr: u32 = 0,
    };
    ///Flash key register
    pub const keyr = RegisterRW(void, keyr_val).init(0x40022000 + 0x4);

    //////////////////////////
    ///OPTKEYR
    const optkeyr_val = packed struct {
        ///OPTKEYR [0:31]
        ///Option byte key
        optkeyr: u32 = 0,
    };
    ///Flash option key register
    pub const optkeyr = RegisterRW(void, optkeyr_val).init(0x40022000 + 0x8);

    //////////////////////////
    ///SR
    const sr_val_read = packed struct {
        ///BSY [0:0]
        ///Busy
        bsy: packed enum(u1) {
            ///No write/erase operation is in progress
            inactive = 0,
            ///A write/erase operation is in progress
            active = 1,
        } = .inactive,
        _unused1: u1 = 0,
        ///PGERR [2:2]
        ///Programming error
        pgerr: u1 = 0,
        _unused3: u1 = 0,
        ///WRPRT [4:4]
        ///Write protection error
        wrprt: u1 = 0,
        ///EOP [5:5]
        ///End of operation
        eop: u1 = 0,
        _unused6: u26 = 0,
    };
    const sr_val_write = packed struct {
        ///BSY [0:0]
        ///Busy
        bsy: u1 = 0,
        _unused1: u1 = 0,
        ///PGERR [2:2]
        ///Programming error
        pgerr: u1 = 0,
        _unused3: u1 = 0,
        ///WRPRT [4:4]
        ///Write protection error
        wrprt: u1 = 0,
        ///EOP [5:5]
        ///End of operation
        eop: u1 = 0,
        _unused6: u26 = 0,
    };
    ///Flash status register
    pub const sr = Register(sr_val).init(0x40022000 + 0xC);

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        ///PG [0:0]
        ///Programming
        pg: packed enum(u1) {
            ///Flash programming activated
            program = 1,
            _zero = 0,
        } = ._zero,
        ///PER [1:1]
        ///Page erase
        per: packed enum(u1) {
            ///Erase activated for selected page
            page_erase = 1,
            _zero = 0,
        } = ._zero,
        ///MER [2:2]
        ///Mass erase
        mer: packed enum(u1) {
            ///Erase activated for all user sectors
            mass_erase = 1,
            _zero = 0,
        } = ._zero,
        _unused3: u1 = 0,
        ///OPTPG [4:4]
        ///Option byte programming
        optpg: packed enum(u1) {
            ///Program option byte activated
            option_byte_programming = 1,
            _zero = 0,
        } = ._zero,
        ///OPTER [5:5]
        ///Option byte erase
        opter: packed enum(u1) {
            ///Erase option byte activated
            option_byte_erase = 1,
            _zero = 0,
        } = ._zero,
        ///STRT [6:6]
        ///Start
        strt: packed enum(u1) {
            ///Trigger an erase operation
            start = 1,
            _zero = 0,
        } = ._zero,
        ///LOCK [7:7]
        ///Lock
        lock: packed enum(u1) {
            ///FLASH_CR register is unlocked
            unlocked = 0,
            ///FLASH_CR register is locked
            locked = 1,
        } = .locked,
        _unused8: u1 = 0,
        ///OPTWRE [9:9]
        ///Option bytes write enable
        optwre: packed enum(u1) {
            ///Option byte write disabled
            disabled = 0,
            ///Option byte write enabled
            enabled = 1,
        } = .disabled,
        ///ERRIE [10:10]
        ///Error interrupt enable
        errie: packed enum(u1) {
            ///Error interrupt generation disabled
            disabled = 0,
            ///Error interrupt generation enabled
            enabled = 1,
        } = .disabled,
        _unused11: u1 = 0,
        ///EOPIE [12:12]
        ///End of operation interrupt
        ///enable
        eopie: packed enum(u1) {
            ///End of operation interrupt disabled
            disabled = 0,
            ///End of operation interrupt enabled
            enabled = 1,
        } = .disabled,
        ///FORCE_OPTLOAD [13:13]
        ///Force option byte loading
        force_optload: packed enum(u1) {
            ///Force option byte loading inactive
            inactive = 0,
            ///Force option byte loading active
            active = 1,
        } = .inactive,
        _unused14: u18 = 0,
    };
    ///Flash control register
    pub const cr = Register(cr_val).init(0x40022000 + 0x10);

    //////////////////////////
    ///AR
    const ar_val = packed struct {
        ///FAR [0:31]
        ///Flash address
        far: u32 = 0,
    };
    ///Flash address register
    pub const ar = RegisterRW(void, ar_val).init(0x40022000 + 0x14);

    //////////////////////////
    ///OBR
    const obr_val = packed struct {
        ///OPTERR [0:0]
        ///Option byte error
        opterr: packed enum(u1) {
            ///The loaded option byte and its complement do not match
            option_byte_error = 1,
            _zero = 0,
        } = ._zero,
        ///RDPRT [1:2]
        ///Read protection level
        ///status
        rdprt: packed enum(u2) {
            ///Level 0
            level0 = 0,
            ///Level 1
            level1 = 1,
            ///Level 2
            level2 = 3,
        } = .level1,
        _unused3: u5 = 0,
        ///WDG_SW [8:8]
        ///WDG_SW
        wdg_sw: packed enum(u1) {
            ///Hardware watchdog
            hardware = 0,
            ///Software watchdog
            software = 1,
        } = .software,
        ///nRST_STOP [9:9]
        ///nRST_STOP
        n_rst_stop: packed enum(u1) {
            ///Reset generated when entering Stop mode
            reset = 0,
            ///No reset generated
            no_reset = 1,
        } = .no_reset,
        ///nRST_STDBY [10:10]
        ///nRST_STDBY
        n_rst_stdby: packed enum(u1) {
            ///Reset generated when entering Standby mode
            reset = 0,
            ///No reset generated
            no_reset = 1,
        } = .no_reset,
        _unused11: u1 = 0,
        ///nBOOT1 [12:12]
        ///BOOT1
        n_boot1: packed enum(u1) {
            ///Together with BOOT0, select the device boot mode
            disabled = 0,
            ///Together with BOOT0, select the device boot mode
            enabled = 1,
        } = .enabled,
        ///VDDA_MONITOR [13:13]
        ///VDDA_MONITOR
        vdda_monitor: packed enum(u1) {
            ///VDDA power supply supervisor disabled
            disabled = 0,
            ///VDDA power supply supervisor enabled
            enabled = 1,
        } = .enabled,
        ///RAM_PARITY_CHECK [14:14]
        ///RAM_PARITY_CHECK
        ram_parity_check: packed enum(u1) {
            ///RAM parity check disabled
            disabled = 1,
            ///RAM parity check enabled
            enabled = 0,
        } = .disabled,
        _unused15: u1 = 0,
        ///Data0 [16:23]
        ///Data0
        data0: u8 = 255,
        ///Data1 [24:31]
        ///Data1
        data1: u8 = 3,
    };
    ///Option byte register
    pub const obr = RegisterRW(obr_val, void).init(0x40022000 + 0x1C);

    //////////////////////////
    ///WRPR
    const wrpr_val = packed struct {
        ///WRP [0:31]
        ///Write protect
        wrp: u32 = 4294967295,
    };
    ///Write protection register
    pub const wrpr = RegisterRW(wrpr_val, void).init(0x40022000 + 0x20);
};

///Debug support
pub const dbgmcu = struct {

    //////////////////////////
    ///IDCODE
    const idcode_val = packed struct {
        ///DEV_ID [0:11]
        ///Device Identifier
        dev_id: u12 = 0,
        ///DIV_ID [12:15]
        ///Division Identifier
        div_id: u4 = 0,
        ///REV_ID [16:31]
        ///Revision Identifier
        rev_id: u16 = 0,
    };
    ///MCU Device ID Code Register
    pub const idcode = RegisterRW(idcode_val, void).init(0x40015800 + 0x0);

    //////////////////////////
    ///CR
    const cr_val = packed struct {
        _unused0: u1 = 0,
        ///DBG_STOP [1:1]
        ///Debug Stop Mode
        dbg_stop: u1 = 0,
        ///DBG_STANDBY [2:2]
        ///Debug Standby Mode
        dbg_standby: u1 = 0,
        _unused3: u29 = 0,
    };
    ///Debug MCU Configuration
    ///Register
    pub const cr = Register(cr_val).init(0x40015800 + 0x4);

    //////////////////////////
    ///APB1_FZ
    const apb1_fz_val = packed struct {
        _unused0: u1 = 0,
        ///DBG_TIM3_STOP [1:1]
        ///TIM3 counter stopped when core is
        ///halted
        dbg_tim3_stop: u1 = 0,
        _unused2: u2 = 0,
        ///DBG_TIM6_STOP [4:4]
        ///TIM6 counter stopped when core is
        ///halted
        dbg_tim6_stop: u1 = 0,
        ///DBG_TIM7_STOP [5:5]
        ///TIM7 counter stopped when core is
        ///halted
        dbg_tim7_stop: u1 = 0,
        _unused6: u2 = 0,
        ///DBG_TIM14_STOP [8:8]
        ///TIM14 counter stopped when core is
        ///halted
        dbg_tim14_stop: u1 = 0,
        _unused9: u2 = 0,
        ///DBG_WWDG_STOP [11:11]
        ///Debug window watchdog stopped when core
        ///is halted
        dbg_wwdg_stop: u1 = 0,
        ///DBG_IWDG_STOP [12:12]
        ///Debug independent watchdog stopped when
        ///core is halted
        dbg_iwdg_stop: u1 = 0,
        _unused13: u8 = 0,
        ///DBG_I2C1_SMBUS_TIMEOUT [21:21]
        ///SMBUS timeout mode stopped when core is
        ///halted
        dbg_i2c1_smbus_timeout: u1 = 0,
        _unused22: u10 = 0,
    };
    ///Debug MCU APB1 freeze register
    pub const apb1_fz = Register(apb1_fz_val).init(0x40015800 + 0x8);

    //////////////////////////
    ///APB2_FZ
    const apb2_fz_val = packed struct {
        _unused0: u11 = 0,
        ///DBG_TIM1_STOP [11:11]
        ///TIM1 counter stopped when core is
        ///halted
        dbg_tim1_stop: u1 = 0,
        _unused12: u4 = 0,
        ///DBG_TIM15_STOP [16:16]
        ///TIM15 counter stopped when core is
        ///halted
        dbg_tim15_stop: u1 = 0,
        ///DBG_TIM16_STOP [17:17]
        ///TIM16 counter stopped when core is
        ///halted
        dbg_tim16_stop: u1 = 0,
        ///DBG_TIM17_STOP [18:18]
        ///TIM17 counter stopped when core is
        ///halted
        dbg_tim17_stop: u1 = 0,
        _unused19: u13 = 0,
    };
    ///Debug MCU APB2 freeze register
    pub const apb2_fz = Register(apb2_fz_val).init(0x40015800 + 0xC);
};

///Universal serial bus full-speed device
///interface
pub const usb = struct {

    //////////////////////////
    ///EP0R
    const ep0r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 0 register
    pub const ep0r = Register(ep0r_val).init(0x40005C00 + 0x0);

    //////////////////////////
    ///EP1R
    const ep1r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 1 register
    pub const ep1r = Register(ep1r_val).init(0x40005C00 + 0x4);

    //////////////////////////
    ///EP2R
    const ep2r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 2 register
    pub const ep2r = Register(ep2r_val).init(0x40005C00 + 0x8);

    //////////////////////////
    ///EP3R
    const ep3r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 3 register
    pub const ep3r = Register(ep3r_val).init(0x40005C00 + 0xC);

    //////////////////////////
    ///EP4R
    const ep4r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 4 register
    pub const ep4r = Register(ep4r_val).init(0x40005C00 + 0x10);

    //////////////////////////
    ///EP5R
    const ep5r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 5 register
    pub const ep5r = Register(ep5r_val).init(0x40005C00 + 0x14);

    //////////////////////////
    ///EP6R
    const ep6r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 6 register
    pub const ep6r = Register(ep6r_val).init(0x40005C00 + 0x18);

    //////////////////////////
    ///EP7R
    const ep7r_val = packed struct {
        ///EA [0:3]
        ///Endpoint address
        ea: u4 = 0,
        ///STAT_TX [4:5]
        ///Status bits, for transmission
        ///transfers
        stat_tx: packed enum(u2) {
            ///all transmission requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all transmission requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all transmission requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for transmission
            valid = 3,
        } = .disabled,
        ///DTOG_TX [6:6]
        ///Data Toggle, for transmission
        ///transfers
        dtog_tx: u1 = 0,
        ///CTR_TX [7:7]
        ///Correct Transfer for
        ///transmission
        ctr_tx: u1 = 0,
        ///EP_KIND [8:8]
        ///Endpoint kind
        ep_kind: u1 = 0,
        ///EP_TYPE [9:10]
        ///Endpoint type
        ep_type: packed enum(u2) {
            ///Bulk endpoint
            bulk = 0,
            ///Control endpoint
            control = 1,
            ///Iso endpoint
            iso = 2,
            ///Interrupt endpoint
            interrupt = 3,
        } = .bulk,
        ///SETUP [11:11]
        ///Setup transaction
        ///completed
        setup: u1 = 0,
        ///STAT_RX [12:13]
        ///Status bits, for reception
        ///transfers
        stat_rx: packed enum(u2) {
            ///all reception requests addressed to this endpoint are ignored
            disabled = 0,
            ///the endpoint is stalled and all reception requests result in a STALL handshake
            stall = 1,
            ///the endpoint is naked and all reception requests result in a NAK handshake
            nak = 2,
            ///this endpoint is enabled for reception
            valid = 3,
        } = .disabled,
        ///DTOG_RX [14:14]
        ///Data Toggle, for reception
        ///transfers
        dtog_rx: u1 = 0,
        ///CTR_RX [15:15]
        ///Correct transfer for
        ///reception
        ctr_rx: u1 = 0,
        _unused16: u16 = 0,
    };
    ///endpoint 7 register
    pub const ep7r = Register(ep7r_val).init(0x40005C00 + 0x1C);

    //////////////////////////
    ///CNTR
    const cntr_val = packed struct {
        ///FRES [0:0]
        ///Force USB Reset
        fres: packed enum(u1) {
            ///Clear USB reset
            no_reset = 0,
            ///Force a reset of the USB peripheral, exactly like a RESET signaling on the USB
            reset = 1,
        } = .reset,
        ///PDWN [1:1]
        ///Power down
        pdwn: packed enum(u1) {
            ///No power down
            disabled = 0,
            ///Enter power down mode
            enabled = 1,
        } = .enabled,
        ///LPMODE [2:2]
        ///Low-power mode
        lpmode: packed enum(u1) {
            ///No low-power mode
            disabled = 0,
            ///Enter low-power mode
            enabled = 1,
        } = .disabled,
        ///FSUSP [3:3]
        ///Force suspend
        fsusp: packed enum(u1) {
            ///No effect
            no_effect = 0,
            ///Enter suspend mode. Clocks and static power dissipation in the analog transceiver are left unaffected
            _suspend = 1,
        } = .no_effect,
        ///RESUME [4:4]
        ///Resume request
        _resume: packed enum(u1) {
            ///Resume requested
            requested = 1,
            _zero = 0,
        } = ._zero,
        ///L1RESUME [5:5]
        ///LPM L1 Resume request
        l1resume: packed enum(u1) {
            ///LPM L1 request requested
            requested = 1,
            _zero = 0,
        } = ._zero,
        _unused6: u1 = 0,
        ///L1REQM [7:7]
        ///LPM L1 state request interrupt
        ///mask
        l1reqm: packed enum(u1) {
            ///L1REQ Interrupt disabled
            disabled = 0,
            ///L1REQ Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///ESOFM [8:8]
        ///Expected start of frame interrupt
        ///mask
        esofm: packed enum(u1) {
            ///ESOF Interrupt disabled
            disabled = 0,
            ///ESOF Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///SOFM [9:9]
        ///Start of frame interrupt
        ///mask
        sofm: packed enum(u1) {
            ///SOF Interrupt disabled
            disabled = 0,
            ///SOF Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///RESETM [10:10]
        ///USB reset interrupt mask
        resetm: packed enum(u1) {
            ///RESET Interrupt disabled
            disabled = 0,
            ///RESET Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///SUSPM [11:11]
        ///Suspend mode interrupt
        ///mask
        suspm: packed enum(u1) {
            ///Suspend Mode Request SUSP Interrupt disabled
            disabled = 0,
            ///SUSP Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///WKUPM [12:12]
        ///Wakeup interrupt mask
        wkupm: packed enum(u1) {
            ///WKUP Interrupt disabled
            disabled = 0,
            ///WKUP Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///ERRM [13:13]
        ///Error interrupt mask
        errm: packed enum(u1) {
            ///ERR Interrupt disabled
            disabled = 0,
            ///ERR Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///PMAOVRM [14:14]
        ///Packet memory area over / underrun
        ///interrupt mask
        pmaovrm: packed enum(u1) {
            ///PMAOVR Interrupt disabled
            disabled = 0,
            ///PMAOVR Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        ///CTRM [15:15]
        ///Correct transfer interrupt
        ///mask
        ctrm: packed enum(u1) {
            ///Correct Transfer (CTR) Interrupt disabled
            disabled = 0,
            ///CTR Interrupt enabled, an interrupt request is generated when the corresponding bit in the USB_ISTR register is set
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///control register
    pub const cntr = Register(cntr_val).init(0x40005C00 + 0x40);

    //////////////////////////
    ///ISTR
    const istr_val = packed struct {
        ///EP_ID [0:3]
        ///Endpoint Identifier
        ep_id: u4 = 0,
        ///DIR [4:4]
        ///Direction of transaction
        dir: packed enum(u1) {
            ///data transmitted by the USB peripheral to the host PC
            to = 0,
            ///data received by the USB peripheral from the host PC
            from = 1,
        } = .to,
        _unused5: u2 = 0,
        ///L1REQ [7:7]
        ///LPM L1 state request
        l1req: packed enum(u1) {
            ///LPM command to enter the L1 state is successfully received and acknowledged
            received = 1,
            _zero = 0,
        } = ._zero,
        ///ESOF [8:8]
        ///Expected start frame
        esof: packed enum(u1) {
            ///an SOF packet is expected but not received
            expected_start_of_frame = 1,
            _zero = 0,
        } = ._zero,
        ///SOF [9:9]
        ///start of frame
        sof: packed enum(u1) {
            ///beginning of a new USB frame and it is set when a SOF packet arrives through the USB bus
            start_of_frame = 1,
            _zero = 0,
        } = ._zero,
        ///RESET [10:10]
        ///reset request
        reset: packed enum(u1) {
            ///peripheral detects an active USB RESET signal at its inputs
            reset = 1,
            _zero = 0,
        } = ._zero,
        ///SUSP [11:11]
        ///Suspend mode request
        susp: packed enum(u1) {
            ///no traffic has been received for 3 ms, indicating a suspend mode request from the USB bus
            _suspend = 1,
            _zero = 0,
        } = ._zero,
        ///WKUP [12:12]
        ///Wakeup
        wkup: packed enum(u1) {
            ///activity is detected that wakes up the USB peripheral
            wakeup = 1,
            _zero = 0,
        } = ._zero,
        ///ERR [13:13]
        ///Error
        err: packed enum(u1) {
            ///One of No ANSwer, Cyclic Redundancy Check, Bit Stuffing or Framing format Violation error occurred
            _error = 1,
            _zero = 0,
        } = ._zero,
        ///PMAOVR [14:14]
        ///Packet memory area over /
        ///underrun
        pmaovr: packed enum(u1) {
            ///microcontroller has not been able to respond in time to an USB memory request
            overrun = 1,
            _zero = 0,
        } = ._zero,
        ///CTR [15:15]
        ///Correct transfer
        ctr: packed enum(u1) {
            ///endpoint has successfully completed a transaction
            completed = 1,
            _zero = 0,
        } = ._zero,
        _unused16: u16 = 0,
    };
    ///interrupt status register
    pub const istr = Register(istr_val).init(0x40005C00 + 0x44);

    //////////////////////////
    ///FNR
    const fnr_val = packed struct {
        ///FN [0:10]
        ///Frame number
        _fn: u11 = 0,
        ///LSOF [11:12]
        ///Lost SOF
        lsof: u2 = 0,
        ///LCK [13:13]
        ///Locked
        lck: packed enum(u1) {
            ///the frame timer remains in this state until an USB reset or USB suspend event occurs
            locked = 1,
            _zero = 0,
        } = ._zero,
        ///RXDM [14:14]
        ///Receive data - line status
        rxdm: packed enum(u1) {
            ///received data minus upstream port data line
            received = 1,
            _zero = 0,
        } = ._zero,
        ///RXDP [15:15]
        ///Receive data + line status
        rxdp: packed enum(u1) {
            ///received data plus upstream port data line
            received = 1,
            _zero = 0,
        } = ._zero,
        _unused16: u16 = 0,
    };
    ///frame number register
    pub const fnr = RegisterRW(fnr_val, void).init(0x40005C00 + 0x48);

    //////////////////////////
    ///DADDR
    const daddr_val = packed struct {
        ///ADD [0:6]
        ///Device address
        add: u7 = 0,
        ///EF [7:7]
        ///Enable function
        ef: packed enum(u1) {
            ///USB device disabled
            disabled = 0,
            ///USB device enabled
            enabled = 1,
        } = .disabled,
        _unused8: u24 = 0,
    };
    ///device address
    pub const daddr = Register(daddr_val).init(0x40005C00 + 0x4C);

    //////////////////////////
    ///BTABLE
    const btable_val = packed struct {
        _unused0: u3 = 0,
        ///BTABLE [3:15]
        ///Buffer table
        btable: u13 = 0,
        _unused16: u16 = 0,
    };
    ///Buffer table address
    pub const btable = Register(btable_val).init(0x40005C00 + 0x50);

    //////////////////////////
    ///LPMCSR
    const lpmcsr_val = packed struct {
        ///LPMEN [0:0]
        ///LPM support enable
        lpmen: packed enum(u1) {
            ///enable the LPM support within the USB device
            disabled = 0,
            ///no LPM transactions are handled
            enabled = 1,
        } = .disabled,
        ///LPMACK [1:1]
        ///LPM Token acknowledge
        ///enable
        lpmack: packed enum(u1) {
            ///the valid LPM Token will be NYET
            nyet = 0,
            ///the valid LPM Token will be ACK
            ack = 1,
        } = .nyet,
        _unused2: u1 = 0,
        ///REMWAKE [3:3]
        ///bRemoteWake value
        remwake: u1 = 0,
        ///BESL [4:7]
        ///BESL value
        besl: u4 = 0,
        _unused8: u24 = 0,
    };
    ///LPM control and status
    ///register
    pub const lpmcsr = Register(lpmcsr_val).init(0x40005C00 + 0x54);

    //////////////////////////
    ///BCDR
    const bcdr_val = packed struct {
        ///BCDEN [0:0]
        ///Battery charging detector (BCD)
        ///enable
        bcden: packed enum(u1) {
            ///disable the BCD support
            disabled = 0,
            ///enable the BCD support within the USB device
            enabled = 1,
        } = .disabled,
        ///DCDEN [1:1]
        ///Data contact detection (DCD) mode
        ///enable
        dcden: packed enum(u1) {
            ///Data contact detection (DCD) mode disabled
            disabled = 0,
            ///Data contact detection (DCD) mode enabled
            enabled = 1,
        } = .disabled,
        ///PDEN [2:2]
        ///Primary detection (PD) mode
        ///enable
        pden: packed enum(u1) {
            ///Primary detection (PD) mode disabled
            disabled = 0,
            ///Primary detection (PD) mode enabled
            enabled = 1,
        } = .disabled,
        ///SDEN [3:3]
        ///Secondary detection (SD) mode
        ///enable
        sden: packed enum(u1) {
            ///Secondary detection (SD) mode disabled
            disabled = 0,
            ///Secondary detection (SD) mode enabled
            enabled = 1,
        } = .disabled,
        ///DCDET [4:4]
        ///Data contact detection (DCD)
        ///status
        dcdet: packed enum(u1) {
            ///data lines contact not detected
            not_detected = 0,
            ///data lines contact detected
            detected = 1,
        } = .not_detected,
        ///PDET [5:5]
        ///Primary detection (PD)
        ///status
        pdet: packed enum(u1) {
            ///no BCD support detected
            no_bcd = 0,
            ///BCD support detected
            bcd = 1,
        } = .no_bcd,
        ///SDET [6:6]
        ///Secondary detection (SD)
        ///status
        sdet: packed enum(u1) {
            ///CDP detected
            cdp = 0,
            ///DCP detected
            dcp = 1,
        } = .cdp,
        ///PS2DET [7:7]
        ///DM pull-up detection
        ///status
        ps2det: packed enum(u1) {
            ///Normal port detected
            normal = 0,
            ///PS2 port or proprietary charger detected
            ps2 = 1,
        } = .normal,
        _unused8: u7 = 0,
        ///DPPU [15:15]
        ///DP pull-up control
        dppu: packed enum(u1) {
            ///signalize disconnect to the host when needed by the user software
            disabled = 0,
            ///enable the embedded pull-up on the DP line
            enabled = 1,
        } = .disabled,
        _unused16: u16 = 0,
    };
    ///Battery charging detector
    pub const bcdr = Register(bcdr_val).init(0x40005C00 + 0x58);
};

///System control block
pub const scb = struct {

    //////////////////////////
    ///CPUID
    const cpuid_val = packed struct {
        ///Revision [0:3]
        ///Revision number
        revision: u4 = 1,
        ///PartNo [4:15]
        ///Part number of the
        ///processor
        part_no: u12 = 3108,
        ///Constant [16:19]
        ///Reads as 0xF
        constant: u4 = 15,
        ///Variant [20:23]
        ///Variant number
        variant: u4 = 0,
        ///Implementer [24:31]
        ///Implementer code
        implementer: u8 = 65,
    };
    ///CPUID base register
    pub const cpuid = RegisterRW(cpuid_val, void).init(0xE000ED00 + 0x0);

    //////////////////////////
    ///ICSR
    const icsr_val = packed struct {
        ///VECTACTIVE [0:5]
        ///Active vector
        vectactive: u6 = 0,
        _unused6: u6 = 0,
        ///VECTPENDING [12:17]
        ///Pending vector
        vectpending: u6 = 0,
        _unused18: u4 = 0,
        ///ISRPENDING [22:22]
        ///Interrupt pending flag
        isrpending: u1 = 0,
        _unused23: u2 = 0,
        ///PENDSTCLR [25:25]
        ///SysTick exception clear-pending
        ///bit
        pendstclr: u1 = 0,
        ///PENDSTSET [26:26]
        ///SysTick exception set-pending
        ///bit
        pendstset: u1 = 0,
        ///PENDSVCLR [27:27]
        ///PendSV clear-pending bit
        pendsvclr: u1 = 0,
        ///PENDSVSET [28:28]
        ///PendSV set-pending bit
        pendsvset: u1 = 0,
        _unused29: u2 = 0,
        ///NMIPENDSET [31:31]
        ///NMI set-pending bit.
        nmipendset: u1 = 0,
    };
    ///Interrupt control and state
    ///register
    pub const icsr = Register(icsr_val).init(0xE000ED00 + 0x4);

    //////////////////////////
    ///AIRCR
    const aircr_val = packed struct {
        _unused0: u1 = 0,
        ///VECTCLRACTIVE [1:1]
        ///VECTCLRACTIVE
        vectclractive: u1 = 0,
        ///SYSRESETREQ [2:2]
        ///SYSRESETREQ
        sysresetreq: u1 = 0,
        _unused3: u12 = 0,
        ///ENDIANESS [15:15]
        ///ENDIANESS
        endianess: u1 = 0,
        ///VECTKEYSTAT [16:31]
        ///Register key
        vectkeystat: u16 = 0,
    };
    ///Application interrupt and reset control
    ///register
    pub const aircr = Register(aircr_val).init(0xE000ED00 + 0xC);

    //////////////////////////
    ///SCR
    const scr_val = packed struct {
        _unused0: u1 = 0,
        ///SLEEPONEXIT [1:1]
        ///SLEEPONEXIT
        sleeponexit: u1 = 0,
        ///SLEEPDEEP [2:2]
        ///SLEEPDEEP
        sleepdeep: u1 = 0,
        _unused3: u1 = 0,
        ///SEVEONPEND [4:4]
        ///Send Event on Pending bit
        seveonpend: u1 = 0,
        _unused5: u27 = 0,
    };
    ///System control register
    pub const scr = Register(scr_val).init(0xE000ED00 + 0x10);

    //////////////////////////
    ///CCR
    const ccr_val = packed struct {
        _unused0: u3 = 0,
        ///UNALIGN__TRP [3:3]
        ///UNALIGN_ TRP
        unalign__trp: u1 = 0,
        _unused4: u5 = 0,
        ///STKALIGN [9:9]
        ///STKALIGN
        stkalign: u1 = 0,
        _unused10: u22 = 0,
    };
    ///Configuration and control
    ///register
    pub const ccr = Register(ccr_val).init(0xE000ED00 + 0x14);

    //////////////////////////
    ///SHPR2
    const shpr2_val = packed struct {
        _unused0: u24 = 0,
        ///PRI_11 [24:31]
        ///Priority of system handler
        ///11
        pri_11: u8 = 0,
    };
    ///System handler priority
    ///registers
    pub const shpr2 = Register(shpr2_val).init(0xE000ED00 + 0x1C);

    //////////////////////////
    ///SHPR3
    const shpr3_val = packed struct {
        _unused0: u16 = 0,
        ///PRI_14 [16:23]
        ///Priority of system handler
        ///14
        pri_14: u8 = 0,
        ///PRI_15 [24:31]
        ///Priority of system handler
        ///15
        pri_15: u8 = 0,
    };
    ///System handler priority
    ///registers
    pub const shpr3 = Register(shpr3_val).init(0xE000ED00 + 0x20);
};

///SysTick timer
pub const stk = struct {

    //////////////////////////
    ///CSR
    const csr_val = packed struct {
        ///ENABLE [0:0]
        ///Counter enable
        enable: u1 = 0,
        ///TICKINT [1:1]
        ///SysTick exception request
        ///enable
        tickint: u1 = 0,
        ///CLKSOURCE [2:2]
        ///Clock source selection
        clksource: u1 = 0,
        _unused3: u13 = 0,
        ///COUNTFLAG [16:16]
        ///COUNTFLAG
        countflag: u1 = 0,
        _unused17: u15 = 0,
    };
    ///SysTick control and status
    ///register
    pub const csr = Register(csr_val).init(0xE000E010 + 0x0);

    //////////////////////////
    ///RVR
    const rvr_val = packed struct {
        ///RELOAD [0:23]
        ///RELOAD value
        reload: u24 = 0,
        _unused24: u8 = 0,
    };
    ///SysTick reload value register
    pub const rvr = Register(rvr_val).init(0xE000E010 + 0x4);

    //////////////////////////
    ///CVR
    const cvr_val = packed struct {
        ///CURRENT [0:23]
        ///Current counter value
        current: u24 = 0,
        _unused24: u8 = 0,
    };
    ///SysTick current value register
    pub const cvr = Register(cvr_val).init(0xE000E010 + 0x8);

    //////////////////////////
    ///CALIB
    const calib_val = packed struct {
        ///TENMS [0:23]
        ///Calibration value
        tenms: u24 = 0,
        _unused24: u6 = 0,
        ///SKEW [30:30]
        ///SKEW flag: Indicates whether the TENMS
        ///value is exact
        skew: u1 = 0,
        ///NOREF [31:31]
        ///NOREF flag. Reads as zero
        noref: u1 = 0,
    };
    ///SysTick calibration value
    ///register
    pub const calib = Register(calib_val).init(0xE000E010 + 0xC);
};
