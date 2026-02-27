const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

const Entry = struct {
    name: []u8,
    kind: std.fs.File.Kind,
    mode: usize,
    size: u64,
};

const Options = struct {
    show_all: bool = false,
    long_format: bool = false,
    human: bool = false,
    path: []const u8 = ".",
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const opts = try parseArgs(arena, args);

    const out = common.stdoutFile();
    const use_color = common.colorEnabled();

    var dir = try std.fs.cwd().openDir(opts.path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    var entries = try std.ArrayList(Entry).initCapacity(arena, 0);

    while (try iter.next()) |item| {
        if (!opts.show_all and item.name.len > 0 and item.name[0] == '.') continue;

        var mode: usize = 0;
        var size: u64 = 0;

        const st = dir.statFile(item.name) catch null;
        if (st) |s| {
            mode = s.mode;
            size = s.size;
        }

        try entries.append(arena, .{
            .name = try arena.dupe(u8, item.name),
            .kind = item.kind,
            .mode = mode,
            .size = size,
        });
    }

    std.mem.sort(Entry, entries.items, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return std.ascii.orderIgnoreCase(a.name, b.name) == .lt;
        }
    }.lessThan);

    for (entries.items) |entry| {
        if (opts.long_format) {
            var perm_buf: [10]u8 = undefined;
            const perms = modeToString(entry.kind, entry.mode, &perm_buf);

            var size_buf: [32]u8 = undefined;
            const size_str = if (opts.human)
                try humanSize(entry.size, &size_buf)
            else
                try std.fmt.bufPrint(&size_buf, "{d}", .{entry.size});

            try common.writeFmt(out, "{s} {s: >8} ", .{ perms, size_str });
        }

        const kind = toFileKind(entry.kind, entry.mode);
        try common.paintByKind(use_color, kind, entry.name, out);
        try out.writeAll("\n");
    }
}

fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) anyerror!Options {
    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-a, --all            Do not ignore entries starting with '.'.
        \\-l, --long           Use a long listing format.
        \\-h, --human-readable With -l, print sizes in human-readable format.
        \\<str>                Directory to list (default: .)
    );

    var diag = clap.Diagnostic{};
    var iter = clap.args.SliceIterator{ .args = args };
    var parsed = clap.parseEx(clap.Help, &params, clap.parsers.default, &iter, .{
        .allocator = allocator,
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

    return .{
        .show_all = parsed.args.all != 0,
        .long_format = parsed.args.long != 0,
        .human = parsed.args.@"human-readable" != 0,
        .path = parsed.positionals[0] orelse ".",
    };
}

fn printHelp() void {
    const out = common.stdoutFile();
    out.writeAll(
        "Usage: zigbox ls [flags] [path]\n\n" ++
            "List directory contents.\n\n" ++
            "Flags:\n" ++
            "  -a, --all               Include hidden files\n" ++
            "  -l, --long              Long listing format\n" ++
            "  -h, --human-readable    Human-readable sizes (with -l)\n" ++
            "      --help              Show this help\n",
    ) catch {};
}

fn toFileKind(kind: std.fs.File.Kind, mode: usize) common.FileKind {
    return switch (kind) {
        .directory => .directory,
        .sym_link => .symlink,
        .file => if ((mode & 0o111) != 0) .executable else .regular,
        else => .other,
    };
}

fn modeToString(kind: std.fs.File.Kind, mode: usize, buf: *[10]u8) []const u8 {
    buf[0] = switch (kind) {
        .directory => 'd',
        .sym_link => 'l',
        else => '-',
    };
    buf[1] = if ((mode & 0o400) != 0) 'r' else '-';
    buf[2] = if ((mode & 0o200) != 0) 'w' else '-';
    buf[3] = if ((mode & 0o100) != 0) 'x' else '-';
    buf[4] = if ((mode & 0o040) != 0) 'r' else '-';
    buf[5] = if ((mode & 0o020) != 0) 'w' else '-';
    buf[6] = if ((mode & 0o010) != 0) 'x' else '-';
    buf[7] = if ((mode & 0o004) != 0) 'r' else '-';
    buf[8] = if ((mode & 0o002) != 0) 'w' else '-';
    buf[9] = if ((mode & 0o001) != 0) 'x' else '-';
    return buf[0..10];
}

fn humanSize(size: u64, buf: *[32]u8) ![]const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };

    var value = @as(f64, @floatFromInt(size));
    var idx: usize = 0;
    while (value >= 1024.0 and idx + 1 < units.len) : (idx += 1) {
        value /= 1024.0;
    }

    if (idx == 0) return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[idx] });
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ value, units[idx] });
}
