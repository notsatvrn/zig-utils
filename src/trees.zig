const std = @import("std");
const Order = std.math.Order;
const Allocator = std.mem.Allocator;

const RedBlack = @import("trees/rb.zig").RedBlackTree;
const Avl = @import("trees/avl.zig").AvlTree;

// GENERIC TREE INTERFACE

pub const Kind = enum { red_black, avl };

pub fn Tree(
    comptime T: type,
    comptime cmp: fn (T, T) Order,
    comptime kind: Kind,
    comptime thread_safe: bool,
) type {
    return struct {
        const Impl = switch (kind) {
            .red_black => RedBlack(T, cmp),
            .avl => Avl(T, cmp),
        };
        const Lock = @import("lock.zig").SharedLock(thread_safe);

        pub const Node = Impl.Node;

        impl: Impl,
        lock: Lock = .{},

        const Self = @This();

        // RE-EXPORTS

        pub inline fn init(allocator: Allocator) Self {
            return .{ .impl = .init(allocator) };
        }

        pub inline fn deinit(self: *Self) void {
            self.lock.lock();
            self.impl.deinit();
            self.* = undefined;
        }

        pub inline fn findNode(self: *Self, value: T) ?*Node {
            self.lock.lockShared();
            defer self.lock.unlockShared();

            var current = self.impl.root;
            if (current == null) return null;
            var ord = Impl.order(value, current.?.value);

            while (true) {
                current = switch (ord) {
                    .lt => current.?.left,
                    .gt => current.?.right,
                    .eq => return current,
                };

                if (current == null) return null;
                ord = Impl.order(value, current.?.value);
            }
        }

        pub inline fn insert(self: *Self, value: T) !void {
            self.lock.lock();
            defer self.lock.unlock();
            try self.impl.insert(value);
        }

        pub inline fn remove(self: *Self, value: T) bool {
            self.lock.lock();
            defer self.lock.unlock();
            return self.impl.delete(value);
        }

        // EXTRA METHODS

        pub inline fn contains(self: *Self, value: T) bool {
            return self.findNode(value) != null;
        }

        pub inline fn min(self: *Self) ?*Node {
            self.lock.lockShared();
            defer self.lock.unlockShared();
            if (self.impl.root) |root| {
                return root.?.min();
            } else return null;
        }

        pub inline fn max(self: *Self) ?*Node {
            self.lock.lockShared();
            defer self.lock.unlockShared();
            if (self.impl.root) |root| {
                return root.?.max();
            } else return null;
        }

        // ITERATOR

        pub inline fn iterator(self: *Self, allocator: Allocator) Iterator {
            return .{ .tree = self, .stack = std.array_list.Managed(*Node).init(allocator) };
        }

        pub const Iterator = struct {
            tree: *Self,
            lock_held: bool = false,

            stack: std.array_list.Managed(*Node),
            exhausted: bool = false,

            pub fn next(self: *Iterator) !?T {
                if (self.exhausted) return null;

                var node: *Node = undefined;
                if (self.stack.pop()) |n| {
                    node = n;
                } else {
                    if (self.tree.impl.root == null) {
                        self.exhausted = true;
                        return null;
                    }

                    if (!self.lock_held) {
                        self.tree.lock.lockShared();
                        self.lock_held = true;
                    }

                    node = self.tree.impl.root.?;
                }

                if (node.left) |left| try self.stack.append(left);
                if (node.right) |right| try self.stack.append(right);

                if (self.stack.items.len == 0) {
                    self.tree.lock.unlockShared();
                    self.lock_held = false;
                    self.exhausted = true;
                }

                return node.value;
            }

            pub fn reset(self: *Iterator) void {
                if (self.lock_held) {
                    self.tree.lock.unlockShared();
                    self.lock_held = false;
                }

                if (!self.exhausted) {
                    self.stack.clearRetainingCapacity();
                } else self.exhausted = false;
            }

            pub fn deinit(self: *Iterator) void {
                self.reset();
                self.stack.deinit();
            }
        };
    };
}

// TREE MAP

pub fn Map(
    comptime K: type,
    comptime V: type,
    comptime cmp: ?fn (K, K) Order,
    comptime kind: Kind,
    comptime thread_safe: bool,
) type {
    return struct {
        const KV = struct { key: K, value: V };
        fn cmpKV(kv1: KV, kv2: KV) Order {
            if (cmp) |f| return f(kv1.key, kv2.key);
            return std.math.order(kv1.key, kv2.key);
        }

        const TreeT = Tree(KV, cmpKV, kind, thread_safe);
        tree: TreeT,

        const Self = @This();

        pub inline fn init(allocator: Allocator) Self {
            return .{ .tree = .init(allocator) };
        }

        pub inline fn deinit(self: *Self) void {
            self.tree.deinit();
            self.* = undefined;
        }

        // READING

        pub inline fn get(self: *Self, key: K) ?V {
            return (self.getEntry(key) orelse return null).value;
        }

        pub fn getEntry(self: *Self, key: K) ?*KV {
            const needle = KV{ .key = key, .value = undefined };
            const node = self.tree.findNode(needle) orelse return null;
            return &node.value;
        }

        pub inline fn contains(self: *Self, key: K) bool {
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

        pub inline fn iterator(self: *Self, allocator: Allocator) TreeT.Iterator {
            return self.tree.iterator(allocator);
        }
    };
}
