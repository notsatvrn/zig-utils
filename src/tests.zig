const std = @import("std");
const builtin = @import("builtin");

const utils = @import("utils");

// ROOT UTILITIES

const EnumStringMap = utils.EnumStringMap;
const readIntPartial = utils.readIntPartial;

// this also covers hash stuff :D
test EnumStringMap {
    const Enum = enum { foo, bar, baz, qux };
    const map = EnumStringMap(Enum, .fastest);
    try std.testing.expectEqual(map.get("foo").?.*, Enum.foo);
}

test readIntPartial {
    const hello = "hello";
    const hello_zero_padded: [8]u8 = hello.* ++ .{0} ** 3;
    const expected: u64 = @bitCast(hello_zero_padded);

    const endian = builtin.cpu.arch.endian();
    const hello_int = readIntPartial(u64, hello, endian);
    try std.testing.expectEqual(expected, hello_int);
}

// TREES

test "trees" {
    inline for ([2]utils.trees.Kind{ .red_black, .avl }) |kind| {
        const Map = utils.trees.Map(usize, []const u8, null, kind);
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
