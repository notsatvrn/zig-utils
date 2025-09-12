pub const hash = @import("hash.zig");
pub const lock = @import("lock.zig");
pub const simd = @import("simd.zig");
pub const trees = @import("trees.zig");

const std = @import("std");
const Endian = std.builtin.Endian;

/// Copies to a zeroed buffer to readInt beyond bounds.
pub inline fn readIntPartial(comptime T: type, input: []const u8, endian: Endian) u64 {
    const len = @min(@sizeOf(T), input.len);
    var buf = [_]u8{0} ** @sizeOf(T);
    @memcpy(buf[0..len], input[0..len]);
    return std.mem.readInt(T, &buf, endian);
}
