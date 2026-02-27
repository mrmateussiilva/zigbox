const std = @import("std");

pub const Color = struct {
    pub const reset = "\x1b[0m";
    pub const blue = "\x1b[34m";
    pub const green = "\x1b[32m";
    pub const cyan = "\x1b[36m";
    pub const yellow = "\x1b[33m";
    pub const red = "\x1b[31m";
};

pub const FileKind = enum {
    directory,
    executable,
    symlink,
    regular,
    other,
};

pub fn stdoutFile() std.fs.File {
    return std.fs.File.stdout();
}

pub fn stderrFile() std.fs.File {
    return std.fs.File.stderr();
}

pub fn colorEnabled() bool {
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "NO_COLOR")) |v| {
        defer std.heap.page_allocator.free(v);
        return false;
    } else |_| {}

    return std.fs.File.stdout().isTty();
}

pub fn writeFmt(file: std.fs.File, comptime fmt: []const u8, args: anytype) !void {
    var stack_buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&stack_buf, fmt, args) catch {
        const heap_msg = try std.fmt.allocPrint(std.heap.page_allocator, fmt, args);
        defer std.heap.page_allocator.free(heap_msg);
        try file.writeAll(heap_msg);
        return;
    };
    try file.writeAll(msg);
}

pub fn paint(enabled: bool, color: []const u8, text: []const u8, file: std.fs.File) !void {
    if (!enabled or std.mem.eql(u8, color, Color.reset)) {
        try file.writeAll(text);
        return;
    }

    try file.writeAll(color);
    try file.writeAll(text);
    try file.writeAll(Color.reset);
}

pub fn paintByKind(enabled: bool, kind: FileKind, text: []const u8, file: std.fs.File) !void {
    const color = switch (kind) {
        .directory => Color.blue,
        .executable => Color.green,
        .symlink => Color.cyan,
        .regular => Color.reset,
        .other => Color.yellow,
    };
    try paint(enabled, color, text, file);
}

pub fn printError(comptime fmt: []const u8, args: anytype) void {
    const errf = stderrFile();
    errf.writeAll(Color.red ++ "error:" ++ Color.reset ++ " ") catch {};
    writeFmt(errf, fmt, args) catch {};
    errf.writeAll("\n") catch {};
}

pub fn printRootHelp() void {
    const out = stdoutFile();
    out.writeAll(
        "zigbox - lightweight Busybox-style coreutils in Zig\n\n" ++
            "Usage:\n" ++
            "  zigbox <subcommand> [options] [args]\n\n" ++
            "Subcommands:\n" ++
            "  ls      List directory contents\n" ++
            "  rm      Remove files/directories\n" ++
            "  find    Find files by name/type\n" ++
            "  grep    Search text in files\n\n" ++
            "Global options:\n" ++
            "  -h, --help    Show this help\n\n" ++
            "Examples:\n" ++
            "  zigbox ls -la .\n" ++
            "  zigbox rm -ri build/\n" ++
            "  zigbox find . -name \"*.zig\" -type f\n" ++
            "  zigbox grep -r \"TODO\" src\n\n" ++
            "Run 'zigbox <subcommand> --help' for command-specific help.\n",
    ) catch {};
}
