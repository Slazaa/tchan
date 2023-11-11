const std = @import("std");

const main = @import("main.zig");

pub const Thread = struct {
    no: u32,
    name: []const u8,
    sub: ?[]const u8 = null,
    com: ?[]const u8 = null,
};

pub const Page = struct {
    threads: []const Thread,
};

pub const JsonResult = main.JsonResult([]const Page);

pub fn makeUrl(string: *std.ArrayList(u8), board: []const u8) !void {
    try string.appendSlice("https://a.4cdn.org/");
    try string.appendSlice(board);
    try string.appendSlice("/catalog.json");
}

pub fn fetch(allocator: std.mem.Allocator, http_client: *std.http.Client, board: []const u8) !JsonResult {
    var url = std.ArrayList(u8).init(allocator);
    defer url.deinit();

    try makeUrl(&url, board);

    var fetch_result = try http_client.fetch(allocator, .{
        .location = .{ .url = url.items },
    });

    errdefer fetch_result.deinit();

    var parsed_json = blk: {
        if (fetch_result.body) |body| {
            break :blk try std.json.parseFromSlice([]const Page, allocator, body, .{
                .ignore_unknown_fields = true,
            });
        } else {
            return error.NoBody;
        }
    };

    errdefer parsed_json.deinit();

    return .{
        .fetch_result = fetch_result,
        .parsed_json = parsed_json,
    };
}
