const std = @import("std");
const Order = std.math.Order;
const Allocator = std.mem.Allocator;

pub fn orderFn(comptime T: type, comptime cmp: ?fn (T, T) Order) fn (T, T) Order {
    return struct {
        pub fn order(x: T, y: T) Order {
            if (cmp) |f| return f(x, y);
            return std.math.order(x, y);
        }
    }.order;
}

pub fn Iterator(comptime Tree: type) type {
    const Node = Tree.Node;
    const T = @FieldType(Node, "value");

    return struct {
        tree: *Tree,
        stack: std.ArrayList(*Node),
        exhausted: bool = false,

        const Self = @This();

        pub inline fn init(tree: *Tree, allocator: Allocator) Self {
            return .{ .tree = tree, .stack = std.ArrayList(*Node).init(allocator) };
        }

        pub fn next(self: *Self) !?T {
            if (self.exhausted) return null;

            var node: *Node = undefined;
            if (self.stack.pop()) |n| {
                node = n;
            } else {
                if (self.tree.root == null) {
                    self.exhausted = true;
                    return null;
                }

                node = self.tree.root.?;
            }

            if (node.left) |left| try self.stack.append(left);
            if (node.right) |right| try self.stack.append(right);

            if (self.stack.items.len == 0)
                self.exhausted = true;

            return node.value;
        }

        pub fn reset(self: *Self) void {
            if (!self.exhausted) {
                self.stack.clearRetainingCapacity();
            } else self.exhausted = false;
        }

        pub fn deinit(self: *Self) void {
            self.reset();
            self.stack.deinit();
        }
    };
}
