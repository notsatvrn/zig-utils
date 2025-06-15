pub const hash = @import("hash.zig");
pub const simd = @import("simd.zig");
pub const spinlock = @import("spinlock.zig");
pub const trees = @import("trees.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const Endian = std.builtin.Endian;

/// Creates a static map of strings to enum values at compile time.
pub fn EnumStringMap(comptime T: type, comptime hasher: hash.Hasher) type {
    const type_info = @typeInfo(T);
    if (type_info != .@"enum") @compileError("enumStringMap with non-enum type");

    const fields = @typeInfo(T).@"enum".fields;
    comptime var out: [fields.len]struct { []const u8, T } = undefined;
    inline for (fields, 0..) |field, i|
        out[i] = .{ field.name, @field(T, field.name) };

    return hash.ComptimeStringHashMap(T, hasher, out);
}

/// Copies to a zeroed buffer to readInt beyond bounds.
pub inline fn readIntPartial(comptime T: type, input: []const u8, endian: Endian) u64 {
    const len = @min(@sizeOf(T), input.len);
    var buf = [_]u8{0} ** @sizeOf(T);
    @memcpy(buf[0..len], input[0..len]);
    return std.mem.readInt(T, &buf, endian);
}
