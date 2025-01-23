const std = @import("std");
const models = @import("models.zig");
const Allocator = std.mem.Allocator;
const Uri = std.Uri;
const Client = std.http.Client;
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const http = std.http;

pub const HttpClient = struct {
    allocator: Allocator,
    base_uri: []const u8,
    headers: StringHashMap([]const u8),
    verbose: bool,

    const Self = @This();

    pub fn init(allocator: Allocator, base_uri: ?[]const u8, api_key: ?[]const u8, verbose: bool) !Self {
        var headers = StringHashMap([]const u8).init(allocator);
        try headers.put("Content-Type", "application/json");

        if (api_key) |key| {
            // Create buffer for first replacement
            var clean_buf: [256]u8 = undefined;
            const clean_len = std.mem.replace(u8, key, "Bearer ", "", &clean_buf);
            const clean_key = clean_buf[0..clean_len];

            // Create buffer for second replacement
            var final_buf: [256]u8 = undefined;
            const final_len = std.mem.replace(u8, clean_key, "bearer ", "", &final_buf);
            const final_key = try allocator.dupe(u8, final_buf[0..final_len]);

            try headers.put("Authorization", final_key);
        }

        const uri = if (base_uri) |uri| uri else "http://localhost:7437";
        const final_uri = if (std.mem.endsWith(u8, uri, "/")) 
            uri[0..uri.len-1] else uri;

        return Self{
            .allocator = allocator,
            .base_uri = final_uri,
            .headers = headers,
            .verbose = verbose,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "Authorization")) {
                self.allocator.free(entry.value_ptr.*);
            }
        }
        self.headers.deinit();
    }

    fn makeRequest(
        self: *Self,
        method: http.Method,
        path: []const u8,
        body: ?[]const u8,
    ) ![]const u8 {
        // Build URL
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}",
            .{ self.base_uri, path }
        );
        defer self.allocator.free(url);

        // Parse URL
        const uri = try Uri.parse(url);

        // Create HTTP client
        var client = Client{ .allocator = self.allocator };
        defer client.deinit();

        // Open connection
        const host = if (uri.host) |h| switch (h) {
            .raw => |str| str,
            .percent_encoded => |str| str,
        } else return error.MissingHost;
        var connection = try client.connect(host, uri.port orelse 80, .plain);
        defer connection.close(self.allocator);

        // Prepare request options
        const options = Client.RequestOptions{
            .connection = connection,
            .server_header_buffer = &[_]u8{},
        };

        // Create request
        var request = try client.open(method, uri, options);
        defer request.deinit();

        // Add headers to request
        var header_iterator = self.headers.iterator();
        while (header_iterator.next()) |entry| {
            const name = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            if (std.mem.eql(u8, name, "Content-Type")) {
                request.headers.content_type = .{ .override = value };
            } else if (std.mem.eql(u8, name, "Authorization")) {
                request.headers.authorization = .{ .override = value };
            } else {
                // Add other headers as extra headers - this might not be correct
                const header = http.Header{ .name = name, .value = value };
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                defer arena.deinit();
                var temp_headers_list = std.ArrayList(http.Header).init(arena.allocator());
                try temp_headers_list.append(header);
                request.extra_headers = temp_headers_list.items;
            }
        }


        // Send request
        try request.send();

        // Write body if present
        if (body) |b| {
            try request.writeAll(b);
            try request.finish();
        }

        // Wait for response
        try request.wait();

        // Get response body
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const body_content = try request.reader().readAllAlloc(arena.allocator(), std.math.maxInt(usize));

        if (self.verbose) {
            std.debug.print("Status: {d}\n", .{request.response.status});
            std.debug.print("Response: {s}\n", .{body_content});
        }

        return if (@as(u16, @intFromEnum(request.response.status)) >= 200 and @as(u16, @intFromEnum(request.response.status)) < 300)
            body_content
        else
            error.ServerError;
    }

    pub fn get(self: *Self, path: []const u8) ![]const u8 {
        return self.makeRequest(.GET, path, null);
    }

    pub fn post(self: *Self, path: []const u8, body: []const u8) ![]const u8 {
        return self.makeRequest(.POST, path, body);
    }

    pub fn put(self: *Self, path: []const u8, body: []const u8) ![]const u8 {
        return self.makeRequest(.PUT, path, body);
    }

    pub fn delete(self: *Self, path: []const u8) ![]const u8 {
        return self.makeRequest(.DELETE, path, null);
    }

    pub fn patch(self: *Self, path: []const u8, body: []const u8) ![]const u8 {
        return self.makeRequest(.PATCH, path, body);
    }

    pub fn handleError(err: anyerror) models.Error {
        return switch (err) {
            error.ServerError => models.Error.ServerError,
            error.OutOfMemory => models.Error.EncodingError,
            error.InvalidCharacter => models.Error.DecodingError,
            else => models.Error.NetworkError,
        };
    }
};