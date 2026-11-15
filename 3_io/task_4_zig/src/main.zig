const std = @import("std");
const buffer_size = 64 * 1024;

fn buildIndex(input: std.fs.File, output: std.fs.File) !u64 {
    var buffer: [buffer_size]u8 = undefined;
    var buffered = std.io.bufferedWriter(output.writer());
    const writer = buffered.writer();

    var offset: u64 = 0;
    var count: u64 = 0;
    var at_line_start = true;
    while (true) {
        const size = try input.read(&buffer);
        if (size == 0) break;
        for (buffer[0..size]) |byte| {
            if (at_line_start) {
                try writer.writeInt(u64, offset, .little);
                count += 1;
            }
            at_line_start = byte == '\n';
            offset = try std.math.add(u64, offset, 1);
        }
    }
    try buffered.flush();
    return count;
}

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    if (args.len != 3) {
        std.debug.print("Usage: line-index INPUT OUTPUT\n", .{});
        return error.InvalidArguments;
    }

    const cwd = std.fs.cwd();
    const input = try cwd.openFile(args[1], .{});
    defer input.close();
    // Exclusive creation also prevents writing through an alias of the input.
    const output = try cwd.createFile(args[2], .{ .exclusive = true });
    errdefer cwd.deleteFile(args[2]) catch {};
    defer output.close();
    const count = try buildIndex(input, output);
    try output.sync();
    std.debug.print("Indexed {d} lines in {s}\n", .{ count, args[2] });
}

pub fn main() void {
    run() catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
