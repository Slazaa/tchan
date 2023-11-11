const std = @import("std");

const boards = @import("boards.zig");
const catalog = @import("catalog.zig");

pub fn JsonResult(comptime T: type) type {
    return struct {
        const Self = @This();

        fetch_result: std.http.Client.FetchResult,
        parsed_json: std.json.Parsed(T),

        pub fn deinit(self: *Self) void {
            self.parsed_json.deinit();
            self.fetch_result.deinit();
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.skip();

    const stdout = std.io.getStdOut().writer();

    try stdout.print("--- 4chan.org ---\n\n", .{});

    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    var result = try boards.fetch(allocator, &http_client);
    defer result.deinit();

    const boards_ = result.parsed_json.value;

    var page_count: ?u32 = null;

    const current_board = blk: {
        const board_input = args_iter.next() orelse {
            for (boards_.boards) |board| {
                try stdout.print("/{s}/ - {s}\n", .{ board.board, board.title });
            }

            return;
        };

        var board_split = std.mem.split(u8, board_input, ":");

        const board = board_split.next() orelse {
            std.log.err("Expected board, found nothing", .{});
            return;
        };

        if (board_split.next()) |page_count_bytes| {
            page_count = std.fmt.parseInt(u32, page_count_bytes, 10) catch {
                std.log.err("Invalid page count", .{});
                return;
            };

            if (page_count.? > 10) {
                std.log.err("Page count limit is 10", .{});
                return;
            }
        }

        break :blk board;
    };

    if (!boards.exists(boards_, current_board)) {
        std.log.err("Invalid board /{s}/", .{current_board});
        return;
    }

    if (args_iter.next()) |thread| {
        _ = thread;
        // Thread
        @panic("Not implemented yet");
    } else {
        var catalog_ = try catalog.fetch(allocator, &http_client, current_board);
        defer catalog_.deinit();

        const pages = if (page_count) |count|
            catalog_.parsed_json.value[0..count]
        else
            catalog_.parsed_json.value;

        for (pages, 1..) |page, page_num| {
            try stdout.print("--- PAGE {} ---\n", .{page_num});

            for (page.threads) |thread| {
                try stdout.print("{} | [{s}]", .{ thread.no, thread.name });

                if (thread.sub) |sub| {
                    try stdout.print(" - {s}", .{sub});
                }

                try stdout.print("\n", .{});

                if (thread.com) |com| {
                    try stdout.print("{s}\n", .{com});
                }

                try stdout.print("\n", .{});
            }
        }
    }
}
