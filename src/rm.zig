const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

const Options = struct {
    force: bool = false,
    recursive: bool = false,
    interactive: bool = false,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var diag = clap.Diagnostic{};
    const params = comptime clap.parseParamsComptime(
        \\--help                 Show this help message.
        \\-f, --force            Ignore nonexistent files and never prompt.
        \\-r, --recursive        Remove directories and their contents recursively.
        \\-i, --interactive      Prompt before every removal.
        \\<str>...               One or more paths to remove.
    );

    var iter = clap.args.SliceIterator{ .args = args };
    var parsed = clap.parseEx(clap.Help, &params, clap.parsers.default, &iter, .{
        .allocator = arena,
        .diagnostic = &diag,
    }) catch |err| {
        diag.reportToFile(.stderr(), err) catch {};
        return error.InvalidArgs;
    };
    defer parsed.deinit();

    if (parsed.args.help != 0) {
        printHelp();
        return error.InvalidArgs;
    }

    const paths = parsed.positionals[0];
    if (paths.len == 0) {
        common.printError("rm: missing operand", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const opts = Options{
        .force = parsed.args.force != 0,
        .recursive = parsed.args.recursive != 0,
        .interactive = parsed.args.interactive != 0,
    };

    for (paths) |path| {
        removePath(path, opts) catch |err| {
            if (opts.force and err == error.FileNotFound) continue;
            common.printError("rm: {s}: {s}", .{ path, @errorName(err) });
            if (!opts.force) return err;
        };
    }
}

fn removePath(path: []const u8, opts: Options) anyerror!void {
    const cwd = std.fs.cwd();

    const st = cwd.statFile(path) catch |err| {
        if (opts.force and err == error.FileNotFound) return;
        return err;
    };

    if (opts.interactive) {
        const ok = try confirm(path);
        if (!ok) return;
    }

    if (st.kind == .directory) {
        if (!opts.recursive) return error.IsDir;
        try cwd.deleteTree(path);
        return;
    }

    try cwd.deleteFile(path);
}

fn confirm(path: []const u8) !bool {
    try common.writeFmt(common.stderrFile(), "remove '{s}'? [y/N] ", .{path});
    var buf: [16]u8 = undefined;
    const n = try std.posix.read(std.posix.STDIN_FILENO, &buf);
    if (n == 0) return false;
    return buf[0] == 'y' or buf[0] == 'Y';
}

fn printHelp() void {
    const out = common.stdoutFile();
    out.writeAll(
        "Usage: zigbox rm [flags] <path>...\n\n" ++
            "Remove files or directories.\n\n" ++
            "Flags:\n" ++
            "  -f, --force         Ignore missing files and never prompt\n" ++
            "  -r, --recursive     Remove directories recursively\n" ++
            "  -i, --interactive   Ask before each removal\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
