const std = @import("std");

const main = @import("main.zig");

pub const Board = struct {
    board: []const u8,
    title: []const u8,
};

pub const Boards = struct {
    boards: []const Board,
};

pub const JsonResult = main.JsonResult(Boards);

pub const url = "https://a.4cdn.org/boards.json";

pub fn fetch(allocator: std.mem.Allocator, http_client: *std.http.Client) !JsonResult {
    var fetch_result = try http_client.fetch(allocator, .{
        .location = .{ .url = url },
    });

    errdefer fetch_result.deinit();

    var parsed_json = blk: {
        if (fetch_result.body) |body| {
            break :blk try std.json.parseFromSlice(Boards, allocator, body, .{
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

pub fn exists(boards: Boards, board_name: []const u8) bool {
    for (boards.boards) |board| {
        if (std.mem.eql(u8, board.board, board_name)) {
            return true;
        }
    }

    return false;
}
