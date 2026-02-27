const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

const Options = struct {
    path: []const u8 = ".",
    name_pattern: ?[]const u8 = null,
    type_filter: ?u8 = null,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const normalized_args = try normalizeFindArgs(arena, args);

    var diag = clap.Diagnostic{};
    const params = comptime clap.parseParamsComptime(
        \\--help                 Show this help message.
        \\-n, --name <str>       Match basename with wildcard (* and ?).
        \\-t, --type <str>       File type: f (file), d (dir), l (symlink).
        \\<str>                  Root path (default: .)
    );

    var iter = clap.args.SliceIterator{ .args = normalized_args };
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

    var opts = Options{};
    opts.path = parsed.positionals[0] orelse ".";
    opts.name_pattern = parsed.args.name;

    if (parsed.args.type) |t| {
        if (t.len != 1 or (t[0] != 'f' and t[0] != 'd' and t[0] != 'l')) {
            common.printError("find: invalid -type value '{s}' (use f, d, or l)", .{t});
            return error.InvalidArgs;
        }
        opts.type_filter = t[0];
    }

    var root = try std.fs.cwd().openDir(opts.path, .{ .iterate = true });
    defer root.close();

    if (matchesPath(opts.path, .directory, opts)) {
        try common.writeFmt(common.stdoutFile(), "{s}\n", .{opts.path});
    }

    var walker = try root.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (!matchesPath(entry.path, entry.kind, opts)) continue;
        try common.writeFmt(common.stdoutFile(), "{s}/{s}\n", .{ opts.path, entry.path });
    }
}

fn normalizeFindArgs(allocator: std.mem.Allocator, args: []const []const u8) ![]const []const u8 {
    var out = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-name")) {
            try out.append(allocator, "--name");
        } else if (std.mem.eql(u8, arg, "-type")) {
            try out.append(allocator, "--type");
        } else {
            try out.append(allocator, arg);
        }
    }
    return out.toOwnedSlice(allocator);
}

fn matchesPath(path: []const u8, kind: std.fs.File.Kind, opts: Options) bool {
    if (opts.type_filter) |tf| {
        const ok = switch (tf) {
            'f' => kind == .file,
            'd' => kind == .directory,
            'l' => kind == .sym_link,
            else => false,
        };
        if (!ok) return false;
    }

    if (opts.name_pattern) |pat| {
        const base = std.fs.path.basename(path);
        if (!globMatch(pat, base)) return false;
    }

    return true;
}

fn globMatch(pattern: []const u8, text: []const u8) bool {
    return globMatchRec(pattern, text, 0, 0);
}

fn globMatchRec(pattern: []const u8, text: []const u8, pi: usize, ti: usize) bool {
    if (pi == pattern.len) return ti == text.len;

    const pc = pattern[pi];
    if (pc == '*') {
        var k = ti;
        while (k <= text.len) : (k += 1) {
            if (globMatchRec(pattern, text, pi + 1, k)) return true;
        }
        return false;
    }

    if (ti == text.len) return false;

    if (pc == '?' or pc == text[ti]) {
        return globMatchRec(pattern, text, pi + 1, ti + 1);
    }

    return false;
}

fn printHelp() void {
    const out = common.stdoutFile();
    out.writeAll(
        "Usage: zigbox find [flags] [path]\n\n" ++
            "Find files and directories.\n\n" ++
            "Flags:\n" ++
            "  -name, --name <pattern>  Basename match with * and ?\n" ++
            "  -type, --type <f|d|l>    Filter by type: file/dir/symlink\n" ++
            "          --help           Show this help\n",
    ) catch {};
}
