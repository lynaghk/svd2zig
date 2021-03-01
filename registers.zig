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
