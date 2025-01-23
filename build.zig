const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add library options
    const options = b.addOptions();
    options.addOption(bool, "enable_logging", true);
    options.addOption([]const u8, "default_base_uri", "http://localhost:7437");

    // Create library
    const lib = b.addStaticLibrary(.{
        .name = "agixt-sdk",
        .root_source_file = b.path("src/sdk.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addOptions("build_options", options);
    b.installArtifact(lib);

    // Create executable
    const exe = b.addExecutable(.{
        .name = "agixt-sdk-example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", options);
    b.installArtifact(exe);

    // Add tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addOptions("build_options", options);

    const model_tests = b.addTest(.{
        .root_source_file = b.path("src/models.zig"),
        .target = target,
        .optimize = optimize,
    });
    model_tests.root_module.addOptions("build_options", options);

    const client_tests = b.addTest(.{
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_tests.root_module.addOptions("build_options", options);

    const auth_tests = b.addTest(.{
        .root_source_file = b.path("src/auth.zig"),
        .target = target,
        .optimize = optimize,
    });
    auth_tests.root_module.addOptions("build_options", options);

    const sdk_tests = b.addTest(.{
        .root_source_file = b.path("src/sdk.zig"),
        .target = target,
        .optimize = optimize,
    });
    sdk_tests.root_module.addOptions("build_options", options);

    const run_main_tests = b.addRunArtifact(main_tests);
    const run_model_tests = b.addRunArtifact(model_tests);
    const run_client_tests = b.addRunArtifact(client_tests);
    const run_auth_tests = b.addRunArtifact(auth_tests);
    const run_sdk_tests = b.addRunArtifact(sdk_tests);

    // Create test step
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_model_tests.step);
    test_step.dependOn(&run_client_tests.step);
    test_step.dependOn(&run_auth_tests.step);
    test_step.dependOn(&run_sdk_tests.step);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}