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

// TESTS

const builtin = @import("builtin");
const EnumStringMap = hash.EnumStringMap;

// this also covers hash stuff :D
test EnumStringMap {
    const Enum = enum { foo, bar, baz, qux };
    const map = EnumStringMap(Enum, hash.nanohash);
    try std.testing.expectEqual(map.get("foo").?, Enum.foo);
    try std.testing.expectEqual(map.get("bar").?, Enum.bar);
    try std.testing.expectEqual(map.get("baz").?, Enum.baz);
    try std.testing.expectEqual(map.get("qux").?, Enum.qux);
}

test readIntPartial {
    const hello = "hello";
    const hello_zero_padded: [8]u8 = hello.* ++ .{0} ** 3;
    const expected: u64 = @bitCast(hello_zero_padded);

    const endian = builtin.cpu.arch.endian();
    const hello_int = readIntPartial(u64, hello, endian);
    try std.testing.expectEqual(expected, hello_int);
}

test trees {
    inline for ([2]trees.Kind{ .red_black, .avl }) |kind| {
        const Map = trees.Map(usize, []const u8, null, kind, false);
        var map = Map.init(std.testing.allocator);
        defer map.deinit();

        try map.put(0, "0");
        try std.testing.expect(map.contains(0));
        try std.testing.expectEqualSlices(u8, map.get(0).?, "0");

        var iter = map.iterator(std.testing.allocator);
        while (try iter.next()) |kv| {
            // we only put 0 -> "0" in here
            try std.testing.expectEqual(kv.key, 0);
            try std.testing.expectEqualSlices(u8, kv.value, "0");
        }
    }
}
