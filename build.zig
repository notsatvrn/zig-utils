const std = @import("std");

pub fn build(b: *std.Build) void {
    // OPTIONS

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const spinlock = b.option(bool, "use_spinlock", "Use spinning locks instead of OS-backed locks") orelse false;

    // DEPENDENCIES

    const comptime_hash_map = b.dependency("comptime_hash_map", .{});
    const chm_module = comptime_hash_map.module("comptime_hash_map");

    // MODULE

    const options = b.addOptions();
    options.addOption(bool, "spinlock", spinlock);
    const options_module = options.createModule();

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "options", .module = options_module },
            .{ .name = "comptime_hash_map", .module = chm_module },
        },
    });

    // TESTS

    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.linkLibC();
    tests.root_module.addImport("utils", utils);

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
