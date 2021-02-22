const std = @import("std");
const winapi = @import("winapi.zig");

const ascii = std.ascii;
const fmt = std.fmt;
const heap = std.heap;
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const Allocator = mem.Allocator;

export fn handlerRoutine(dwCtrlType: winapi.DWORD) winapi.BOOL {
    return switch (dwCtrlType) {
        winapi.CTRL_C_EVENT => winapi.TRUE,
        winapi.CTRL_BREAK_EVENT => winapi.TRUE,
        winapi.CTRL_CLOSE_EVENT => winapi.TRUE,
        winapi.CTRL_LOGOFF_EVENT => winapi.TRUE,
        winapi.CTRL_SHUTDOWN_EVENT => winapi.TRUE,
        else => winapi.FALSE,
    };
}

fn removeSuffix(comptime T: type, slice: []const T, suffix: []const T) []const T {
    if (mem.endsWith(u8, slice, suffix)) {
        return slice[0 .. slice.len - suffix.len];
    } else {
        return slice;
    }
}

fn pathWithExtension(allocator: *mem.Allocator, path: []const u8, extension: []const u8) ![]const u8 {
    const path_extension = fs.path.extension(path);
    const path_no_extension = removeSuffix(u8, path, path_extension);
    return fmt.allocPrint(allocator, "{}.{}", .{ path_no_extension, extension });
}

fn trimSpaces(comptime T: type, slice: []const T) []const T {
    return mem.trim(T, slice, &ascii.spaces);
}

pub fn main() anyerror!void {
    const gpa = heap.c_allocator;

    // Collect arguments
    const args = try process.argsAlloc(gpa);
    defer process.argsFree(gpa, args);

    // Shim filename
    var program_path = try fs.selfExePathAlloc(gpa);
    defer gpa.free(program_path);
    var shim_path = pathWithExtension(gpa, program_path, "shim") catch {
        std.log.crit("Cannot make out shim path.", .{});
        return;
    };
    defer gpa.free(shim_path);

    // Place to store the shim file contents
    var cfg = std.BufMap.init(gpa);
    defer cfg.deinit();

    // Open shim file for reading
    var shim_file = fs.cwd().openFile(shim_path, .{}) catch {
        std.log.crit("Unable to open shim file. ({})", .{shim_path});
        return;
    };
    defer shim_file.close();

    // Go through the shim file and collect key-value pairs
    var reader = shim_file.reader();
    var line_buf: [1024 * 2]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        // Find index of equals, if it doesn't exist we just skip this line
        const equals_index = mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trimSpaces(u8, line[0..equals_index]);
        const value = trimSpaces(u8, line[equals_index + 1 .. line.len]);
        // Put in the map
        try cfg.set(key, value);
    }

    // Arguments sent to the child
    var cmd_args = std.ArrayList([]const u8).init(gpa);
    defer cmd_args.deinit();

    // Add the program name from the path
    if (cfg.get("path")) |cfg_path| {
        try cmd_args.append(cfg_path);
    } else {
        std.log.crit("Path not found in shim file", .{});
        return;
    }

    // Pass all arguments except program name
    for (args[1..]) |arg| {
        try cmd_args.append(arg);
    }

    // Pass all arguments from shim file
    if (cfg.get("args")) |cfg_args| {
        var it = mem.split(cfg_args, " ");
        while (it.next()) |cfg_arg| {
            try cmd_args.append(cfg_arg);
        }
    }

    if (winapi.SetConsoleCtrlHandler(handlerRoutine, winapi.TRUE) != winapi.TRUE) {
        std.log.crit("Cannot set ctrl handler", .{});
        return;
    }

    // Spawn child process
    var child = try std.ChildProcess.init(cmd_args.items, gpa);
    defer child.deinit();
    _ = try child.spawnAndWait();
}
