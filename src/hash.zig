const std = @import("std");
const readInt = std.mem.readInt;
const readIntPartial = @import("root.zig").readIntPartial;

// ALGORITHMS

const seed: u64 = 0x3243F6A8885A308D; // digits of pi

/// Hash function which only "hashes" the first 8 bytes.
/// Never use this unless you know your inputs will be <= 8 bytes.
pub fn nanohash(input: []const u8) u64 {
    if (input.len > 8) {
        @branchHint(.unlikely);
        return seed;
    }

    const int = readIntPartial(u64, input, .little);
    return mix(int, seed) ^ input.len;
}

// folded multiply with a faster 32-bit path
// borrowed from foldhash and modified a bit
inline fn mix(x: u64, y: u64) u64 {
    const builtin = @import("builtin");
    const target = builtin.target;
    const cpu = builtin.cpu;

    // sparc64 and wasm64 do not have 128-bit widening multiplication
    // x86-64 and aarch64 should have it regardless of abi, but abi may reduce ptr bit width
    // Zig 0.14.1 doesn't have wide arithmetic in the wasm feature set, add a check for that eventually
    const wide_mul = (target.ptrBitWidth() == 64 and cpu.arch != .sparc64 and cpu.arch != .wasm64) or
        (cpu.arch == .x86_64 or cpu.arch.isAARCH64());

    if (wide_mul) {
        const full = @as(u128, x) * @as(u128, y);
        const lo: u64 = @truncate(full);
        const hi: u64 = @truncate(full >> 64);
        return lo ^ hi;
    }

    // we don't need a super accurate approximation, so we do half the work here that foldhash does
    // this should still do a good job of mixing bits around, but it's a lot faster

    const lx: u32 = @truncate(x);
    const ly: u32 = @truncate(y);
    const hx: u32 = @truncate(x >> 32);
    const hy: u32 = @truncate(y >> 32);

    const ll = @as(u64, lx) * @as(u64, ly);
    const hh = @as(u64, hx) * @as(u64, hy);

    return ll ^ hh;
}

/// Hash function optimized for small strings.
pub fn microhash(input: []const u8) u64 {
    var ptr = input.ptr;
    var len = input.len;
    var out = seed ^ len;

    while (len > 16) : (len -= 16) {
        const x = readInt(u64, @ptrCast(ptr), .little);
        const y = readInt(u64, @ptrCast(ptr + 8), .little);
        out = mix(out ^ x, y);
        out = std.math.rotr(u64, out, 23);
        ptr += 16;
    }

    if (len > 8) {
        const x = readInt(u64, @ptrCast(ptr), .little);
        const y = readIntPartial(u64, (ptr + 8)[0 .. len - 8], .little);
        out = mix(out ^ x, y);
    } else if (len > 0) {
        const x = readIntPartial(u64, ptr[0..len], .little);
        out = mix(out, x);
    }

    return out;
}

/// Hash function which can be used for any strings.
pub fn wyhash(input: []const u8) u64 {
    return @call(.always_inline, std.hash.Wyhash.hash, .{ seed, input });
}

// FAST STRING HASHMAPS

pub fn StringContext(comptime hasher: fn ([]const u8) u64, comptime T: type) type {
    return struct {
        pub fn hash(_: @This(), s: []const u8) T {
            return @truncate(hasher(s));
        }
        pub fn eql(_: @This(), a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    };
}

pub fn StringHashMap(comptime V: type, comptime hasher: fn ([]const u8) u64) type {
    return std.HashMap([]const u8, V, StringContext(hasher, u64), std.hash_map.default_max_load_percentage);
}
pub fn StringHashMapUnmanaged(comptime V: type, comptime hasher: fn ([]const u8) u64) type {
    return std.HashMapUnmanaged([]const u8, V, StringContext(hasher, u64), std.hash_map.default_max_load_percentage);
}

pub fn StringArrayHashMap(comptime V: type, comptime hasher: fn ([]const u8) u64) type {
    return std.ArrayHashMap([]const u8, V, StringContext(hasher, u32), true);
}
pub fn StringArrayHashMapUnmanaged(comptime V: type, comptime hasher: fn ([]const u8) u64) type {
    return std.ArrayHashMapUnmanaged([]const u8, V, StringContext(hasher, u32), true);
}

pub fn ComptimeStringHashMap(comptime V: type, comptime hasher: fn ([]const u8) u64, comptime values: anytype) type {
    const chm = @import("comptime_hash_map");

    comptime var min_len = std.math.maxInt(usize);
    comptime var max_len = 0;
    for (values) |kv| {
        const key: []const u8 = kv.@"0";
        min_len = @min(key.len, min_len);
        max_len = @max(key.len, max_len);
    }

    return struct {
        const map = chm.ComptimeHashMap([]const u8, V, StringContext(hasher, u64), values);

        pub fn has(key: []const u8) bool {
            return get(key) != null;
        }

        pub fn get(key: []const u8) ?V {
            if (key.len < min_len or key.len > max_len) return null;
            // hopefully this will optimize away the reference
            const value = @call(.always_inline, map.get, .{key});
            return if (value) |v| v.* else null;
        }
    };
}

// FAST STRING -> ENUM HASHMAPS

/// Creates a static map of strings to enum values at compile time.
pub fn EnumStringMap(comptime T: type, comptime hasher: fn ([]const u8) u64) type {
    const type_info = @typeInfo(T);
    if (type_info != .@"enum") @compileError("enumStringMap with non-enum type");

    const fields = @typeInfo(T).@"enum".fields;
    comptime var out: [fields.len]struct { []const u8, T } = undefined;
    inline for (fields, 0..) |field, i|
        out[i] = .{ field.name, @field(T, field.name) };

    return ComptimeStringHashMap(T, hasher, out);
}
