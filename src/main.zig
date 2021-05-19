const std = @import("std");
const win = std.os.windows;

const ascii = std.ascii;
const fmt = std.fmt;
const heap = std.heap;
const fs = std.fs;
const mem = std.mem;
const process = std.process;

export fn handlerRoutine(dwCtrlType: win.DWORD) callconv(win.WINAPI) win.BOOL {
    return switch (dwCtrlType) {
        win.CTRL_C_EVENT => win.TRUE,
        win.CTRL_BREAK_EVENT => win.TRUE,
        win.CTRL_CLOSE_EVENT => win.TRUE,
        win.CTRL_LOGOFF_EVENT => win.TRUE,
        win.CTRL_SHUTDOWN_EVENT => win.TRUE,
        else => win.FALSE,
    };
}

// removeSuffix removes the suffix from the slice
fn removeSuffix(comptime T: type, slice: []const T, suffix: []const T) []const T {
    if (mem.endsWith(u8, slice, suffix)) {
        return slice[0 .. slice.len - suffix.len];
    } else {
        return slice;
    }
}

// pathWithExtension returns the path with the specified extension
fn pathWithExtension(allocator: *mem.Allocator, path: []const u8, extension: []const u8) ![]const u8 {
    const path_extension = fs.path.extension(path);
    const path_no_extension = removeSuffix(u8, path, path_extension);
    return fmt.allocPrint(allocator, "{s}.{s}", .{ path_no_extension, extension });
}

// trimSpaces removes spaces from the beginning and end of a string
fn trimSpaces(slice: []const u8) []const u8 {
    return mem.trim(u8, slice, &ascii.spaces);
}

pub fn main() anyerror!void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const ally = &arena.allocator;

    // Collect arguments
    const args = try process.argsAlloc(ally);

    // Shim filename
    var program_path = try fs.selfExePathAlloc(ally);
    var shim_path = pathWithExtension(ally, program_path, "shim") catch {
        std.log.crit("Cannot make out shim path.", .{});
        return;
    };

    // Place to store the shim file contents
    var cfg = std.BufMap.init(ally);

    // Open shim file for reading
    var shim_file = fs.openFileAbsolute(shim_path, .{}) catch {
        std.log.crit("Unable to open shim file. ({s})", .{shim_path});
        return;
    };
    defer shim_file.close();

    // Go through the shim file and collect key-value pairs
    var reader = shim_file.reader();
    var line_buf: [1024]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        // The lines should look like this: `key = value`
        // Find index of equals, if it doesn't exist we just skip this line
        const equals_index = mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trimSpaces(line[0..equals_index]);
        const value = trimSpaces(line[equals_index + 1 .. line.len]);
        try cfg.set(key, value);
    }

    // Arguments sent to the child process
    var cmd_args = std.ArrayList([]const u8).init(ally);

    // Add the program name from shim file
    if (cfg.get("path")) |cfg_path| {
        try cmd_args.append(cfg_path);
    } else {
        std.log.crit("`path` not found in shim file", .{});
        return;
    }

    // Pass all arguments from our process except program name
    try cmd_args.appendSlice(args[1..]);

    // Pass all arguments from shim file
    if (cfg.get("args")) |cfg_args| {
        var it = mem.split(cfg_args, " ");
        while (it.next()) |cfg_arg| {
            try cmd_args.append(cfg_arg);
        }
    }

    try win.SetConsoleCtrlHandler(handlerRoutine, true);

    // Spawn child process
    var child = try std.ChildProcess.init(cmd_args.items, ally);
    _ = try child.spawnAndWait();
}
