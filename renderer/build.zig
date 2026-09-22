const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raster = b.addModule("frameshift_raster", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const executable = b.addExecutable(.{
        .name = "frameshift-raster",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "frameshift_raster", .module = raster }},
        }),
    });
    b.installArtifact(executable);

    const module_tests = b.addTest(.{ .root_module = raster });
    const run_module_tests = b.addRunArtifact(module_tests);

    const executable_tests = b.addTest(.{ .root_module = executable.root_module });
    const run_executable_tests = b.addRunArtifact(executable_tests);

    const test_step = b.step("test", "Run renderer tests");
    test_step.dependOn(&run_module_tests.step);
    test_step.dependOn(&run_executable_tests.step);
}
