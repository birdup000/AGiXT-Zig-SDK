# AGiXT Zig SDK

[![GitHub](https://img.shields.io/badge/GitHub-Sponsor%20Josh%20XT-blue?logo=github&style=plastic)](https://github.com/sponsors/Josh-XT) [![PayPal](https://img.shields.io/badge/PayPal-Sponsor%20Josh%20XT-blue.svg?logo=paypal&style=plastic)](https://paypal.me/joshxt) [![Ko-Fi](https://img.shields.io/badge/Kofi-Sponsor%20Josh%20XT-blue.svg?logo=kofi&style=plastic)](https://ko-fi.com/joshxt)

[![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20Core-blue?logo=github&style=plastic)](https://github.com/Josh-XT/AGiXT) [![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20Hub-blue?logo=github&style=plastic)](https://github.com/AGiXT/hub) [![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20NextJS%20Web%20UI-blue?logo=github&style=plastic)](https://github.com/AGiXT/nextjs) [![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20Streamlit%20Web%20UI-blue?logo=github&style=plastic)](https://github.com/AGiXT/streamlit)

[![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20Python%20SDK-blue?logo=github&style=plastic)](https://github.com/AGiXT/python-sdk) [![pypi](https://img.shields.io/badge/pypi-AGiXT%20Python%20SDK-blue?logo=pypi&style=plastic)](https://pypi.org/project/agixtsdk/)

[![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20TypeScript%20SDK-blue?logo=github&style=plastic)](https://github.com/AGiXT/typescript-sdk) [![npm](https://img.shields.io/badge/npm-AGiXT%20TypeScript%20SDK-blue?logo=npm&style=plastic)](https://www.npmjs.com/package/agixt)

[![GitHub](https://img.shields.io/badge/GitHub-AGiXT%20Dart%20SDK-blue?logo=github&style=plastic)](https://github.com/AGiXT/dart-sdk)

[![Discord](https://img.shields.io/discord/1097720481970397356?label=Discord&logo=discord&logoColor=white&style=plastic&color=5865f2)](https://discord.gg/d3TkHRZcjD)
[![Twitter](https://img.shields.io/badge/Twitter-Follow_@Josh_XT-blue?logo=twitter&style=plastic)](https://twitter.com/Josh_XT)

[![Logo](https://josh-xt.github.io/AGiXT/images/AGiXT-gradient-flat.svg)](https://josh-xt.github.io/AGiXT/)

A Zig implementation of the AGiXT SDK for interacting with AGiXT API endpoints. This SDK provides a native Zig interface for managing agents, conversations, and other AGiXT functionality.

## Features

- Agent Management (create, delete, update, list)
- Conversation Handling (create, manage, interact)
- Authentication Support (user registration, login)
- Chat and Instruction Capabilities
- Memory Management
- Command Execution
- Chain Operations
- Extensible Design

## Requirements

- Zig 0.11.0 or later
- AGiXT Server (running locally or remote)

## Installation

1. Add the SDK to your project:

```zig
// build.zig.zon
.{
    .dependencies = .{
        .agixt_sdk = .{
            .url = "https://github.com/birdup000/AGiXT-Zig-SDK/archive/refs/tags/v0.1.0.tar.gz",
            // Add appropriate hash after release
        },
    },
}
```

2. Include in your build.zig:

```zig
const agixt_sdk_dep = b.dependency("agixt_sdk", .{
    .target = target,
    .optimize = optimize,
});
exe.addModule("agixt_sdk", agixt_sdk_dep.module("agixt_sdk"));
```

## Usage Example

```zig
const std = @import("std");
const AGiXTSDK = @import("agixt_sdk").AGiXTSDK;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the SDK
    var client = try AGiXTSDK.init(
        allocator,
        null,  // default base_uri: http://localhost:7437
        null,  // no API key
        true,  // verbose mode
    );
    defer client.deinit();

    // Create an agent
    const new_agent = try client.addAgent(
        "test_agent",
        .{ .provider = "gpt4free" },
        null,
        null,
    );

    // Start a conversation
    const conversation = try client.newConversation(
        "test_agent",
        "test_conversation",
        null,
    );

    // Chat with the agent
    const response = try client.chat(
        "test_agent",
        "Hello, how are you?",
        "test_conversation",
        4,
    );
    std.debug.print("Agent response: {s}\n", .{response});
}
```

## Documentation

This Zig SDK provides a comprehensive interface for interacting with the AGiXT API. It supports agent management, conversation handling, authentication, and more. Below are code snippets illustrating basic usage. For detailed API usage, please refer to the source code in `src/sdk.zig`.

### Usage Examples

#### Initialize SDK
```zig
    var client = try AGiXTSDK.init(
        allocator,
        null,  // default base_uri: http://localhost:7437
        null,  // no API key
        true,  // verbose mode
    );
    defer client.deinit();
```

#### Create Agent
```zig
    const new_agent = try client.addAgent(
        "test_agent",
        .{ .provider = "gpt4free" },
        null,
        null,
    );
```

#### Start Conversation
```zig
    const conversation = try client.newConversation(
        "test_agent",
        "test_conversation",
        null,
    );
```

#### Chat with Agent
```zig
    const response = try client.chat(
        "test_agent",
        "Hello, how are you?",
        "test_conversation",
        4,
    );
    std.debug.print("Agent response: {s}\n", .{response});
```

### Error Handling

The SDK uses Zig's error union type. Example:

```zig
const result = client.addAgent("agent_name", settings, null, null) catch |err| {
    switch (err) {
        error.NetworkError => std.debug.print("Network error\n", .{}),
        error.ServerError => std.debug.print("Server error\n", .{}),
        else => std.debug.print("Unknown error\n", .{}),
    }
    return;
};
```

For a complete list of functions and error types, please refer to the source code.


## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- AGiXT Team for the original Python SDK
- Zig community for the amazing programming language

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- AGiXT Team for the original Python SDK
- Zig community for the amazing programming language

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.
