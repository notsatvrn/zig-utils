const rb = @import("trees/rb.zig");
const avl = @import("trees/avl.zig");
const common = @import("trees/common.zig");

pub const RedBlack = rb.RedBlackTree;
pub const Avl = avl.AvlTree;

// TREE MAP

const std = @import("std");
const Order = std.math.Order;
const Allocator = std.mem.Allocator;

pub const Kind = enum { red_black, avl };

pub fn Map(
    comptime K: type,
    comptime V: type,
    comptime cmp: ?fn (K, K) Order,
    comptime kind: Kind,
) type {
    return struct {
        const KV = struct { key: K, value: V };
        fn cmpKV(kv1: KV, kv2: KV) Order {
            return common.orderFn(K, cmp)(kv1.key, kv2.key);
        }

        const Tree = switch (kind) {
            .red_black => RedBlack(KV, cmpKV),
            .avl => Avl(KV, cmpKV),
        };

        tree: Tree,

        const Self = @This();

        pub inline fn init(allocator: Allocator) Self {
            return .{ .tree = Tree.init(allocator) };
        }

        pub inline fn deinit(self: *Self) void {
            self.tree.deinit();
            self.* = undefined;
        }

        // READING

        pub inline fn get(self: Self, key: K) ?V {
            return (self.getEntry(key) orelse return null).value;
        }

        pub fn getEntry(self: Self, key: K) ?*KV {
            const needle = KV{ .key = key, .value = undefined };
            const node = self.tree.findNode(needle) orelse return null;
            return &node.value;
        }

        pub inline fn contains(self: Self, key: K) bool {
            return self.getEntry(key) != null;
        }

        // WRITING

        pub inline fn put(self: *Self, key: K, value: V) !void {
            try self.tree.insert(.{ .key = key, .value = value });
        }

        pub inline fn remove(self: *Self, key: K) bool {
            return self.tree.remove(.{ .key = key, .value = undefined });
        }

        // ITERATOR

        pub inline fn iterator(self: *Self, allocator: Allocator) Tree.Iterator {
            return self.tree.iterator(allocator);
        }
    };
}
