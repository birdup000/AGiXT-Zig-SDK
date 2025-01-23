const std = @import("std");

pub const ChatCompletions = struct {
    model: []const u8 = "gpt4free",  // This is the agent name
    messages: ?[]Message = null,
    temperature: ?f32 = 0.9,
    top_p: ?f32 = 1.0,
    tools: ?[]Tool = null,
    tools_choice: ?[]const u8 = "auto",
    n: ?i32 = 1,
    stream: ?bool = false,
    stop: ?[][]const u8 = null,
    max_tokens: ?i32 = 4096,
    presence_penalty: ?f32 = 0.0,
    frequency_penalty: ?f32 = 0.0,
    logit_bias: ?std.StringHashMap(f32) = null,
    user: ?[]const u8 = "Chat",  // This is the conversation name
};

pub const Message = struct {
    role: []const u8,
    content: MessageContent,
    tts: ?bool = null,
};

pub const MessageContent = union(enum) {
    text: []const u8,
    list: []ContentItem,
};

pub const ContentItem = struct {
    text: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    audio_url: ?[]const u8 = null,
    video_url: ?[]const u8 = null,
    file_url: ?[]const u8 = null,
};

pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    input_schema: std.json.Value,
};

pub const ResponseMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatResponse = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []Choice,
    usage: Usage,
};

pub const Choice = struct {
    index: i32,
    message: ResponseMessage,
    finish_reason: []const u8,
    logprobs: ?std.json.Value,
};

pub const Usage = struct {
    prompt_tokens: i32,
    completion_tokens: i32,
    total_tokens: i32,
};

pub const Error = error{
    InvalidRequest,
    AuthenticationFailed,
    NetworkError,
    ServerError,
    DecodingError,
    EncodingError,
};