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
            "  grep    Search text in files\n" ++
            "  cat     Print file contents\n" ++
            "  mkdir   Create directories\n" ++
            "  touch   Create empty files\n" ++
            "  pwd     Print current directory\n" ++
            "  echo    Print text\n" ++
            "  cp      Copy files/directories\n" ++
            "  mv      Move/rename files/directories\n\n" ++
            "Global options:\n" ++
            "  -h, --help    Show this help\n\n" ++
            "Examples:\n" ++
            "  zigbox ls -la .\n" ++
            "  zigbox rm -ri build/\n" ++
            "  zigbox find . -name \"*.zig\" -type f\n" ++
            "  zigbox grep -r \"TODO\" src\n" ++
            "  zigbox mkdir -p tmp/demo\n" ++
            "  zigbox touch tmp/demo/file.txt\n" ++
            "  zigbox cat tmp/demo/file.txt\n" ++
            "  zigbox cp tmp/demo/file.txt /tmp/\n" ++
            "  zigbox mv /tmp/file.txt /tmp/file2.txt\n\n" ++
            "Run 'zigbox <subcommand> --help' for command-specific help.\n",
    ) catch {};
}

pub fn renderProgress(op: []const u8, path: []const u8, done: u64, total: u64) !void {
    var buf: [256]u8 = undefined;
    const pct: u64 = if (total == 0) 100 else @min(100, (done * 100) / total);
    const width: u64 = 24;
    const fill: usize = @intCast((pct * width) / 100);

    var i: usize = 0;
    while (i < width) : (i += 1) {
        buf[i] = if (i < fill) '#' else '-';
    }

    try writeFmt(stderrFile(), "\r{s} [{s}] {d:>3}% {s}", .{ op, buf[0..width], pct, path });
}

pub fn finishProgress() !void {
    try stderrFile().writeAll("\n");
}
