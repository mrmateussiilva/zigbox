const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

const Options = struct {
    recursive: bool = false,
    pattern: []const u8,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var diag = clap.Diagnostic{};
    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-r, --recursive      Recurse into directories.
        \\<str>                Pattern to search for.
        \\<str>...             One or more files/directories.
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

    const pattern = parsed.positionals[0] orelse {
        common.printError("grep: missing pattern", .{});
        printHelp();
        return error.InvalidArgs;
    };

    const opts = Options{
        .recursive = parsed.args.recursive != 0,
        .pattern = pattern,
    };

    const targets = parsed.positionals[1];
    if (targets.len == 0) {
        try common.writeFmt(common.stderrFile(), "grep: no path provided; use files or -r <dir>\n", .{});
        return;
    }

    const multiple = targets.len > 1;
    for (targets) |path| {
        try grepPath(allocator, path, opts, multiple);
    }
}

fn grepPath(allocator: std.mem.Allocator, path: []const u8, opts: Options, multiple: bool) anyerror!void {
    const cwd = std.fs.cwd();
    const st = cwd.statFile(path) catch |err| {
        common.printError("grep: cannot access '{s}': {s}", .{ path, @errorName(err) });
        return;
    };

    switch (st.kind) {
        .file => try grepFile(path, opts.pattern, multiple),
        .directory => {
            if (!opts.recursive) {
                common.printError("grep: {s}: is a directory (use -r)", .{path});
                return;
            }

            var dir = try cwd.openDir(path, .{ .iterate = true });
            defer dir.close();

            var walker = try dir.walk(allocator);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                if (entry.kind != .file) continue;

                const joined = try std.fs.path.join(allocator, &.{ path, entry.path });
                defer allocator.free(joined);

                try grepFile(joined, opts.pattern, true);
            }
        },
        else => {},
    }
}

fn grepFile(path: []const u8, pattern: []const u8, show_path: bool) !void {
    const cwd = std.fs.cwd();
    var f = cwd.openFile(path, .{}) catch return;
    defer f.close();

    const content = try f.readToEndAlloc(std.heap.page_allocator, 64 * 1024 * 1024);
    defer std.heap.page_allocator.free(content);

    var it = std.mem.splitScalar(u8, content, '\n');
    var line_no: usize = 0;

    while (it.next()) |line| {
        line_no += 1;
        if (std.mem.indexOf(u8, line, pattern) == null) continue;

        if (show_path) {
            try common.writeFmt(common.stdoutFile(), "{s}:{d}:{s}\n", .{ path, line_no, line });
        } else {
            try common.writeFmt(common.stdoutFile(), "{d}:{s}\n", .{ line_no, line });
        }
    }
}

fn printHelp() void {
    const out = common.stdoutFile();
    out.writeAll(
        "Usage: zigbox grep [flags] <pattern> [path...]\n\n" ++
            "Search for a string in files.\n\n" ++
            "Flags:\n" ++
            "  -r, --recursive     Recurse directories\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
