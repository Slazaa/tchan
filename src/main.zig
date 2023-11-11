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

    const current_board = args_iter.next() orelse {
        std.log.err("Expected board, found nothing", .{});
        return;
    };

    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    var result = try boards.fetch(allocator, &http_client);
    defer result.deinit();

    const boards_ = result.parsed_json.value;

    const stdout = std.io.getStdOut().writer();

    if (std.mem.eql(u8, current_board, "-l") or std.mem.eql(u8, current_board, "--list")) {
        try stdout.print("--- 4Chan board list | 4chan.org ---\n", .{});

        for (boards_.boards) |board| {
            try stdout.print("/{s}/ - {s}\n", .{ board.board, board.title });
        }

        return;
    }

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

        const threads = catalog_.parsed_json.value[0].threads;

        for (threads) |thread| {
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
