const std = @import("std");
const windows = std.os.windows;

export fn handlerRoutine(dwCtrlType: windows.DWORD) callconv(windows.WINAPI) windows.BOOL {
    return switch (dwCtrlType) {
        windows.CTRL_C_EVENT,
        windows.CTRL_BREAK_EVENT,
        windows.CTRL_CLOSE_EVENT,
        windows.CTRL_LOGOFF_EVENT,
        windows.CTRL_SHUTDOWN_EVENT,
        => windows.TRUE,
        else => windows.FALSE,
    };
}

/// removes the suffix from the slice.
fn removeSuffix(comptime T: type, slice: []const T, suffix: []const T) []const T {
    return if (std.mem.endsWith(T, slice, suffix))
        slice[0 .. slice.len - suffix.len]
    else
        slice;
}

test "removeSuffix" {
    const actual = removeSuffix(u8, "hello world", "world");
    try std.testing.expectEqualStrings("hello ", actual);
}

/// returns the path with the specified extension. caller owns returned memory.
fn pathWithExtension(
    allocator: std.mem.Allocator,
    path: []const u8,
    extension: []const u8,
) ![]const u8 {
    const path_extension = std.fs.path.extension(path);
    const path_no_extension = removeSuffix(u8, path, path_extension);
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ path_no_extension, extension });
}

test "pathWithExtension" {
    var example = try pathWithExtension(std.testing.allocator, "mem.tar", "exe");
    defer std.testing.allocator.free(example);
    try std.testing.expectEqualStrings("mem.exe", example);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    // Shim filename matches our name
    const program_path = try std.fs.selfExePathAlloc(allocator);
    const shim_path = pathWithExtension(allocator, program_path, "shim") catch {
        std.log.err("Cannot make out shim path.", .{});
        return;
    };

    // Place to store the shim file key-value pairs
    var cfg = std.BufMap.init(allocator);

    const shim_file = std.fs.openFileAbsolute(shim_path, .{}) catch {
        std.log.err("Unable to open shim file. ({s})", .{shim_path});
        return;
    };
    defer shim_file.close();

    // Go through the shim file and collect key-value pairs
    const reader = shim_file.reader();
    var line_buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        // The lines should look like this: `key = value`
        var iterator = std.mem.tokenize(u8, line, "= ");
        const key = iterator.next() orelse continue;
        const value = iterator.next() orelse continue;
        try cfg.put(key, value);
    }

    // Arguments sent to the child process
    var cmd_args = std.ArrayList([]const u8).init(allocator);

    // Add the program name from shim file
    if (cfg.get("path")) |cfg_path| {
        try cmd_args.append(cfg_path);
    } else {
        std.log.err("`path` not found in shim file", .{});
        return;
    }

    // Pass all arguments from our process except program name
    try cmd_args.appendSlice(args[1..]);

    // Pass all arguments from shim file
    if (cfg.get("args")) |cfg_args| {
        var iterator = std.mem.tokenize(u8, cfg_args, " ");
        while (iterator.next()) |arg| {
            try cmd_args.append(arg);
        }
    }

    try windows.SetConsoleCtrlHandler(handlerRoutine, true);

    // Run the actual program.
    var child = std.ChildProcess.init(cmd_args.items, allocator);
    _ = try child.spawnAndWait();
}
