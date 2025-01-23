const std = @import("std");
const client = @import("client.zig");
const models = @import("models.zig");
const Allocator = std.mem.Allocator;
const json = std.json;

pub const Auth = struct {
    http_client: *client.HttpClient,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, http_client: *client.HttpClient) Self {
        return Self{
            .allocator = allocator,
            .http_client = http_client,
        };
    }

    pub fn login(self: *Self, email: []const u8, otp: []const u8) ![]const u8 {
        const body = try json.stringify(.{
            .email = email,
            .token = otp,
        }, .{}, self.allocator);
        defer self.allocator.free(body);

        const response = try self.http_client.post("/v1/login", body);
        defer self.allocator.free(response);

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("detail")) |detail| {
            if (std.mem.indexOf(u8, detail.string, "?token=")) |token_start| {
                const token = detail.string[token_start + 7..];
                // Update client headers with new token
                try self.http_client.headers.put("Authorization", try self.allocator.dupe(u8, token));
                return try self.allocator.dupe(u8, token);
            }
        }

        return error.AuthenticationFailed;
    }

    pub fn registerUser(
        self: *Self, 
        email: []const u8, 
        first_name: []const u8, 
        last_name: []const u8
    ) ![]const u8 {
        const body = try json.stringify(.{
            .email = email,
            .first_name = first_name,
            .last_name = last_name,
        }, .{}, self.allocator);
        defer self.allocator.free(body);

        const response = try self.http_client.post("/v1/user", body);
        defer self.allocator.free(response);

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response, std.math.maxInt(usize));
        defer parsed.deinit();

        if (parsed.value.object.get("otp_uri")) |otp_uri| {
            const uri = otp_uri.string;
            if (std.mem.indexOf(u8, uri, "secret=")) |secret_start| {
                if (std.mem.indexOf(u8, uri[secret_start..], "&")) |end_offset| {
                    // Extract the full URI with properly computed indices
                    const full_uri = uri[0..secret_start + end_offset];
                    return try self.allocator.dupe(u8, full_uri);
                }
            }
        }

        return error.RegistrationFailed;
    }

    pub fn userExists(self: *Self, email: []const u8) !bool {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/v1/user/exists?email={s}",
            .{email}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.get(path);
        defer self.allocator.free(response);

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        defer parsed.deinit();

        return parsed.value.bool;
    }

    pub fn updateUser(self: *Self, args: std.StringHashMap([]const u8)) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const response = try self.http_client.put(
            "/v1/user",
            try json.stringify(args.unmanaged, .{}, arena.allocator())
        );
        defer self.allocator.free(response);
    }

    pub fn getUser(self: *Self) !std.json.Value {
        const response = try self.http_client.get("/v1/user");
        defer self.allocator.free(response);

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        return parsed.value;
    }

    pub fn oauth2Login(
        self: *Self,
        provider: []const u8,
        code: []const u8,
        referrer: ?[]const u8
    ) !std.json.Value {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const body = if (referrer) |ref|
            try json.stringify(.{
                .code = code,
                .referrer = ref,
            }, .{}, arena.allocator())
        else
            try json.stringify(.{
                .code = code,
            }, .{}, arena.allocator());

        const path = try std.fmt.allocPrint(
            self.allocator,
            "/v1/oauth2/{s}",
            .{provider}
        );
        defer self.allocator.free(path);

        const response = try self.http_client.post(path, body);
        defer self.allocator.free(response);

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response);
        return parsed.value;
    }
};