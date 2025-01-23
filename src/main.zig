const std = @import("std");
const sdk = @import("sdk.zig");
const models = @import("models.zig");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example usage of AGiXTSDK
    var client = try sdk.AGiXTSDK.init(
        allocator,
        null, // Uses default base_uri: http://localhost:7437
        null, // No API key
        true, // Verbose mode enabled
    );
    defer client.deinit();

    // Example: List all agents
    const agents = client.getAgents() catch |err| {
        std.debug.print("Failed to get agents: {}\n", .{err});
        return;
    };
    defer allocator.free(agents);
    std.debug.print("Available agents: {s}\n", .{agents});

    // Example: Create a new agent
    var settings = std.json.Value{
        .object = std.json.ObjectMap.init(allocator)
    };
    try settings.object.put("provider", .{ .string = "gpt4free" });
    try settings.object.put("temperature", .{ .float = 0.7 });
    const agent_name = "test_agent";
    
    const new_agent = try client.addAgent(
        agent_name,
        settings,
        null,  // No custom commands
        null,  // No training URLs
    );
    defer allocator.free(new_agent);
    std.debug.print("Created new agent: {s}\n", .{new_agent});

    // Example: Start a conversation
    const conversation = client.newConversation(
        agent_name,
        "test_conversation",
        null,  // No initial content
    ) catch |err| {
        std.debug.print("Failed to create conversation: {}\n", .{err});
        return;
    };
    defer allocator.free(conversation);
    std.debug.print("Started conversation: {s}\n", .{conversation});

    // Example: Send a chat message
    const response = client.chat(
        agent_name,
        "Hello, how are you?",
        "test_conversation",
        4,  // context_results
    ) catch |err| {
        std.debug.print("Failed to chat: {}\n", .{err});
        return;
    };
    defer allocator.free(response);
    std.debug.print("Agent response: {s}\n", .{response});

    // Example: Clean up by deleting the test agent
    const delete_result = client.deleteAgent(agent_name) catch |err| {
        std.debug.print("Failed to delete agent: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_result);
    std.debug.print("Delete result: {s}\n", .{delete_result});
}

test "basic AGiXT SDK functionality" {
    // Initialize test allocator
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create SDK instance
    var client = try sdk.AGiXTSDK.init(
        allocator,
        null,
        null,
        false,
    );
    defer client.deinit();

    // Test agent creation
    const agent_name = "test_agent";
    var settings = std.json.Value{
        .object = std.json.ObjectMap.init(allocator)
    };
    try settings.object.put("provider", .{ .string = "gpt4free" });
    try settings.object.put("temperature", .{ .float = 0.7 });

    _ = try client.addAgent(
        agent_name,
        settings,
        null,
        null,
    );

    // Get list of agents
    const agents = try client.getAgents();
    try std.testing.expect(agents.len > 0);

    // Test conversation creation
    const conv_name = "test_conversation";
    _ = try client.newConversation(
        agent_name,
        conv_name,
        null,
    );

    // Get conversations
    const conversations = try client.getConversations();
    try std.testing.expect(conversations.len > 0);

    // Clean up
    _ = try client.deleteAgent(agent_name);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "agixt-sdk",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}