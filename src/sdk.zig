const std = @import("std");
const auth = @import("auth.zig");
const client = @import("client.zig");
const models = @import("models.zig");
const Allocator = std.mem.Allocator;
const json = std.json;

pub const AGiXTSDK = struct {
    allocator: Allocator,
    http_client: client.HttpClient,
    auth_client: auth.Auth,

    const Self = @This();

    pub fn init(allocator: Allocator, base_uri: ?[]const u8, api_key: ?[]const u8, verbose: bool) !Self {
        var http = try client.HttpClient.init(allocator, base_uri, api_key, verbose);
        return Self{
            .allocator = allocator,
            .http_client = http,
            .auth_client = auth.Auth.init(allocator, &http),
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
    }

    // Agent Management Functions
    pub fn getAgents(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/agent");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("agents")) |agents| {
            return try std.json.stringifyAlloc(self.allocator, agents, .{});
        }
        return error.InvalidResponse;
    }

    pub fn addAgent(
        self: *Self,
        agent_name: []const u8,
        settings: ?std.json.Value,
        commands: ?std.json.Value,
        training_urls: ?[]const []const u8,
    ) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const empty_settings = std.json.Value{ .object = std.json.ObjectMap.init(arena.allocator()) };
        const empty_commands = std.json.Value{ .object = std.json.ObjectMap.init(arena.allocator()) };

        var buf = std.ArrayList(u8).init(arena.allocator());
        try json.stringify(.{
            .agent_name = agent_name,
            .settings = settings orelse empty_settings,
            .commands = commands orelse empty_commands,
            .training_urls = training_urls orelse &[_][]const u8{},
        }, .{}, buf.writer());

        return try self.http_client.post("/api/agent", buf.items);
    }

    pub fn getAgentConfig(self: *Self, agent_name: []const u8) !std.json.Value {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}",
            .{agent_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("agent")) |agent| {
            return agent;
        }
        return error.InvalidResponse;
    }

    pub fn updateAgentSettings(
        self: *Self,
        agent_name: []const u8,
        settings: std.json.Value,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .settings = settings,
            .agent_name = agent_name,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    pub fn deleteAgent(self: *Self, agent_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}",
            .{agent_name}
        );
        defer self.allocator.free(path);

        return try self.http_client.delete(path);
    }

    pub fn importAgent(
        self: *Self,
        agent_name: []const u8,
        settings: ?std.json.Value,
        commands: ?std.json.Value,
    ) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const empty_settings = std.json.Value{ .object = std.json.ObjectMap.init(arena.allocator()) };
        const empty_commands = std.json.Value{ .object = std.json.ObjectMap.init(arena.allocator()) };

        var buf = std.ArrayList(u8).init(arena.allocator());
        try json.stringify(.{
            .agent_name = agent_name,
            .settings = settings orelse empty_settings,
            .commands = commands orelse empty_commands,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/agent/import", buf.items);
    }

    pub fn renameAgent(self: *Self, agent_name: []const u8, new_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .new_name = new_name,
        }, .{}, buf.writer());

        return try self.http_client.patch(path, buf.items);
    }

    pub fn updateAgentCommands(
        self: *Self,
        agent_name: []const u8,
        commands: std.json.Value,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/commands",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .commands = commands,
            .agent_name = agent_name,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    // Conversation Management Functions
    pub fn getConversationsWithIds(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/conversations?with_ids=true");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("conversations_with_ids")) |conversations| {
            return try std.json.stringifyAlloc(self.allocator, conversations, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getConversations(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/conversations");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("conversations")) |conversations| {
            return try std.json.stringifyAlloc(self.allocator, conversations, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getConversation(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
        limit: u32,
        page: u32,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .conversation_name = conversation_name,
            .agent_name = agent_name,
            .limit = limit,
            .page = page,
        }, .{}, buf.writer());

        const response = try self.http_client.get("/api/conversation");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("conversation_history")) |history| {
            return try std.json.stringifyAlloc(self.allocator, history, .{});
        }
        return error.InvalidResponse;
    }

    pub fn newConversation(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
        conversation_content: ?[]const std.json.Value,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .conversation_name = conversation_name,
            .agent_name = agent_name,
            .conversation_content = conversation_content orelse &[_]std.json.Value{},
        }, .{}, buf.writer());

        return try self.http_client.post("/api/conversation", buf.items);
    }

    pub fn deleteConversation(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .conversation_name = conversation_name,
            .agent_name = agent_name,
        }, .{}, buf.writer());

        return try self.http_client.delete("/api/conversation");
    }

    pub fn forkConversation(
        self: *Self,
        conversation_name: []const u8,
        message_id: []const u8,
    ) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var buf = std.ArrayList(u8).init(arena.allocator());
        defer buf.deinit();
        try json.stringify(.{
            .conversation_name = conversation_name,
            .message_id = message_id,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/conversation/fork", buf.items);
    }

    pub fn renameConversation(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
        new_name: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .conversation_name = conversation_name,
            .new_conversation_name = new_name,
            .agent_name = agent_name,
        }, .{}, buf.writer());

        return try self.http_client.put("/api/conversation", buf.items);
    }
    // Chain Management Functions
    pub fn getChains(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/chain");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("chains")) |chains| {
            return try std.json.stringifyAlloc(self.allocator, chains, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getChain(self: *Self, chain_name: []const u8) ![]const u8 {
        const response = try self.http_client.get("/api/chain/{s}", .{chain_name});
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("chain")) |chain| {
            return try std.json.stringifyAlloc(self.allocator, chain, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getChainResponses(self: *Self, chain_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/responses",
            .{chain_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("chain")) |chain| {
            return try std.json.stringifyAlloc(self.allocator, chain, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getChainArgs(self: *Self, chain_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/args",
            .{chain_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("chain_args")) |chain_args| {
            return try std.json.stringifyAlloc(self.allocator, chain_args, .{});
        }
        return error.InvalidResponse;
    }

    pub fn runChain(
        self: *Self,
        chain_name: []const u8,
        user_input: []const u8,
        agent_name: []const u8,
        all_responses: bool,
        from_step: u32,
        chain_args: std.json.Value,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt = user_input,
            .agent_override = agent_name,
            .all_responses = all_responses,
            .from_step = from_step,
            .chain_args = chain_args,
        }, .{}, buf.writer());

        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/run",
            .{chain_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.post(path, buf.items);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("response")) |response_text| {
            return try std.json.stringifyAlloc(self.allocator, response_text, .{});
        }
        return error.InvalidResponse;
    }

    pub fn runChainStep(
        self: *Self,
        chain_name: []const u8,
        step_number: u32,
        user_input: []const u8,
        agent_name: []const u8,
        chain_args: std.json.Value,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt = user_input,
            .agent_override = agent_name,
            .chain_args = chain_args,
        }, .{}, buf.writer());

        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/run/step/{d}",
            .{ chain_name, step_number }
        );
        defer self.allocator.free(path);

        const response = try self.http_client.post(path, buf.items);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("response")) |response_text| {
            return try std.json.stringifyAlloc(self.allocator, response_text, .{});
        }
        return error.InvalidResponse;
    }

    pub fn addChain(self: *Self, chain_name: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .chain_name = chain_name,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/chain", buf.items);
    }

    pub fn importChain(self: *Self, chain_name: []const u8, steps: std.json.Value) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .chain_name = chain_name,
            .steps = steps,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/chain/import", buf.items);
    }

    pub fn renameChain(self: *Self, chain_name: []const u8, new_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}",
            .{chain_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .new_name = new_name,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    pub fn deleteChain(self: *Self, chain_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}",
            .{chain_name}
        );
        defer self.allocator.free(path);

        return try self.http_client.delete(path);
    }

    pub fn addStep(
        self: *Self,
        chain_name: []const u8,
        step_number: u32,
        agent_name: []const u8,
        prompt_type: []const u8,
        prompt: std.json.Value,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .chain_name = chain_name,
            .step_number = step_number,
            .agent_name = agent_name,
            .prompt_type = prompt_type,
            .prompt = prompt,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/chain/{s}/step", buf.items);
    }

    pub fn updateStep(
        self: *Self,
        chain_name: []const u8,
        step_number: u32,
        agent_name: []const u8,
        prompt_type: []const u8,
        prompt: std.json.Value,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/step/{d}",
            .{ chain_name, step_number }
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .step_number = step_number,
            .agent_name = agent_name,
            .prompt_type = prompt_type,
            .prompt = prompt,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    pub fn moveStep(
        self: *Self,
        
        old_step_number: u32,
        new_step_number: u32,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .old_step_number = old_step_number,
            .new_step_number = new_step_number,
        }, .{}, buf.writer());

        return try self.http_client.patch("/api/chain/{s}/step/move", buf.items);
    }

    pub fn deleteStep(self: *Self, chain_name: []const u8, step_number: u32) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/chain/{s}/step/{d}",
            .{ chain_name, step_number }
        );
        defer self.allocator.free(path);

        return try self.http_client.delete(path);
    }
    // Prompt Management Functions
    pub fn addPrompt(
        self: *Self,
        prompt_name: []const u8,
        prompt: []const u8,
        prompt_category: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt_name = prompt_name,
            .prompt = prompt,
            .prompt_category = prompt_category,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/prompt/{s}", buf.items);
    }

    pub fn getPromptCategories(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/prompt/categories");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("prompt_categories")) |categories| {
            return try std.json.stringifyAlloc(self.allocator, categories, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getPromptArgs(self: *Self, prompt_category: []const u8, prompt_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}/{s}/args",
            .{prompt_category, prompt_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("prompt_args")) |prompt_args| {
            return try std.json.stringifyAlloc(self.allocator, prompt_args, .{});
        }
        return error.InvalidResponse;
    }
    pub fn getPrompt(self: *Self, prompt_category: []const u8, prompt_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}/{s}",
            .{prompt_category, prompt_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("prompt")) |prompt| {
            return try std.json.stringifyAlloc(self.allocator, prompt, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getPrompts(self: *Self, prompt_category: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}",
            .{prompt_category}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("prompts")) |prompts| {
            return try std.json.stringifyAlloc(self.allocator, prompts, .{});
        }
        return error.InvalidResponse;
    }

    pub fn deletePrompt(self: *Self, prompt_name: []const u8, prompt_category: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}/{s}",
            .{prompt_category, prompt_name}
        );
        defer self.allocator.free(path);

        return try self.http_client.delete(path);
    }

    pub fn updatePrompt(
        self: *Self,
        prompt_name: []const u8,
        prompt: []const u8,
        prompt_category: []const u8,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}/{s}",
            .{prompt_category, prompt_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt_name = prompt_name,
            .prompt = prompt,
            .prompt_category = prompt_category,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    pub fn renamePrompt(self: *Self, prompt_name: []const u8, new_name: []const u8, prompt_category: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/prompt/{s}/{s}",
            .{prompt_category, prompt_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt_name = new_name,
        }, .{}, buf.writer());

        return try self.http_client.patch(path, buf.items);
    }

    pub fn getPersona(self: *Self, agent_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/persona",
            .{agent_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("persona")) |persona| {
            return try std.json.stringifyAlloc(self.allocator, persona, .{});
        }
        return error.InvalidResponse;
    }

    pub fn updatePersona(self: *Self, agent_name: []const u8, persona: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/persona",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .persona = persona,
        }, .{}, buf.writer());

        return try self.http_client.put(path, buf.items);
    }

    // Provider and Embedder Functions
    pub fn getProviders(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/provider");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("providers")) |providers| {
            return try std.json.stringifyAlloc(self.allocator, providers, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getProvidersByService(self: *Self, service: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/providers/service/{s}",
            .{service}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("providers")) |providers| {
            return try std.json.stringifyAlloc(self.allocator, providers, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getProviderSettings(self: *Self, provider_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/provider/{s}",
            .{provider_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("settings")) |settings| {
            return try std.json.stringifyAlloc(self.allocator, settings, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getEmbedProviders(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/embedding_providers");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("providers")) |providers| {
            return try std.json.stringifyAlloc(self.allocator, providers, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getEmbedders(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/embedders");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("embedders")) |embedders| {
            return try std.json.stringifyAlloc(self.allocator, embedders, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getEmbeddersDetails(self: *Self) ![]const u8 {
        const response = try self.http_client.get("/api/embedders");
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("embedders")) |embedders| {
            return try std.json.stringifyAlloc(self.allocator, embedders, .{});
        }
        return error.InvalidResponse;
    }

    pub fn getAgentExtensions(self: *Self, agent_name: []const u8) ![]const u8 {
        const response = try self.http_client.get("/api/extensions/{s}/args", .{agent_name});
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("command_args")) |command_args| {
            return try std.json.stringifyAlloc(self.allocator, command_args, .{});
        }
        return error.InvalidResponse;
    }

    // Agent Prompt and Command Management Functions
    pub fn getCommands(self: *Self, agent_name: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/command",
            .{agent_name}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("commands")) |commands| {
            return try std.json.stringifyAlloc(self.allocator, commands, .{});
        }
        return error.InvalidResponse;
    }

    pub fn toggleCommand(self: *Self, agent_name: []const u8, command_name: []const u8, enable: bool) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/command",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .command_name = command_name,
            .enable = enable,
        }, .{}, buf.writer());

        const response = try self.http_client.patch(path, buf.items);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        if (parsed.value.object.get("message")) |message| {
            return try std.json.stringifyAlloc(self.allocator, message, .{});
        }
        return error.InvalidResponse;
    }

    pub fn executeCommand(
        self: *Self,
        agent_name: []const u8,
        command_name: []const u8,
        command_args: std.json.Value,
        conversation_name: []const u8,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/command",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .command_name = command_name,
            .command_args = command_args,
            .conversation_name = conversation_name,
        }, .{}, buf.writer());

        return try self.http_client.post(path, buf.items);
    }

    pub fn smartInstruct(
        self: *Self,
        agent_name: []const u8,
        user_input: []const u8,
        conversation: []const u8,
    ) ![]const u8 {
        return try self.runChain(
            "Smart Instruct",
            user_input,
            agent_name,
            false,
            1,
            .{
                .conversation_name = conversation,
                .disable_memory = true,
            },
        );
    }

    pub fn smartChat(
        self: *Self,
        agent_name: []const u8,
        user_input: []const u8,
        conversation: []const u8,
    ) ![]const u8 {
        return try self.runChain(
            "Smart Chat",
            user_input,
            agent_name,
            false,
            1,
            .{
                .conversation_name = conversation,
                .disable_memory = true,
            },
        );
    }

    // Chat Interactions
    pub fn chat(
        self: *Self,
        agent_name: []const u8,
        user_input: []const u8,
        conversation: []const u8,
        context_results: u32,
    ) ![]const u8 {
        return try self.promptAgent(
            agent_name,
            "Chat",
            .{
                .user_input = user_input,
                .context_results = context_results,
                .conversation_name = conversation,
                .disable_memory = true,
            },
        );
    }

    pub fn updateConversationMessage(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
        message: []const u8,
        new_message: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .message = message,
            .new_message = new_message,
            .agent_name = agent_name,
            .conversation_name = conversation_name,
        }, .{}, buf.writer());

        return try self.http_client.put("/api/conversation/message", buf.items);
    }

    pub fn deleteConversationMessage(
        self: *Self,
        agent_name: []const u8,
        conversation_name: []const u8,
        message: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .message = message,
            .agent_name = agent_name,
            .conversation_name = conversation_name,
        }, .{}, buf.writer());

        return try self.http_client.delete("/api/conversation/message");
    }

    pub fn instruct(
        self: *Self,
        agent_name: []const u8,
        user_input: []const u8,
        conversation: []const u8,
    ) ![]const u8 {
        return try self.promptAgent(
            agent_name,
            "instruct",
            .{
                .user_input = user_input,
                .disable_memory = true,
                .conversation_name = conversation,
            },
        );
    }

    pub fn newConversationMessage(
        self: *Self,
        role: []const u8,
        message: []const u8,
        conversation_name: []const u8,
    ) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .role = role,
            .message = message,
            .conversation_name = conversation_name,
        }, .{}, buf.writer());

        return try self.http_client.post("/api/conversation/message", buf.items);
    }

    fn promptAgent(
        self: *Self,
        agent_name: []const u8,
        prompt_name: []const u8,
        prompt_args: anytype,
    ) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/api/agent/{s}/prompt",
            .{agent_name}
        );
        defer self.allocator.free(path);

        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(.{
            .prompt_name = prompt_name,
            .prompt_args = prompt_args,
        }, .{}, buf.writer());

        const response = try self.http_client.post(path, buf.items);
        var parsed = try json.parseFromSlice(json.Value, self.allocator, response, .{});
        defer parsed.deinit();

        if (parsed.value.object.get("response")) |response_text| {
            return try std.json.stringifyAlloc(self.allocator, response_text, .{});
        }
        return error.InvalidResponse;
    }
    // User Management Functions
    pub fn login(self: *Self, email: []const u8, otp: []const u8) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var buf = std.ArrayList(u8).init(arena.allocator());
        try json.stringify(.{
            .email = email,
            .token = otp,
        }, .{}, buf.writer());

        return try self.http_client.post("/v1/login", buf.items);
    }

    pub fn registerUser(self: *Self, email: []const u8, first_name: []const u8, last_name: []const u8) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var buf = std.ArrayList(u8).init(arena.allocator());
        try json.stringify(.{
            .email = email,
            .first_name = first_name,
            .last_name = last_name,
        }, .{}, buf.writer());

        return try self.http_client.post("/v1/user", buf.items);
    }

    pub fn userExists(self: *Self, email: []const u8) ![]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/v1/user/exists?email={s}",
            .{email}
        );
        defer self.allocator.free(path);

        return try self.http_client.get(path);
    }

    pub fn updateUser(self: *Self, kwargs: std.json.Value) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        try json.stringify(kwargs, .{}, buf.writer());

        return try self.http_client.put("/v1/user", buf.items);
    }

    pub fn getUser(self: *Self) ![]const u8 {
        return try self.http_client.get("/v1/user");
    }
};