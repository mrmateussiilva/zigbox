const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub const Options = struct {
    recursive: bool = false,
    force: bool = false,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help                Show this help message.
        \\-r, --recursive       Copy directories recursively.
        \\-f, --force           Overwrite destination files.
        \\<str>...              Source(s) and destination.
    );

    var diag = clap.Diagnostic{};
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

    const pos = parsed.positionals[0];
    if (pos.len < 2) {
        common.printError("cp: expected <src...> <dst>", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const opts = Options{
        .recursive = parsed.args.recursive != 0,
        .force = parsed.args.force != 0,
    };

    const dst = pos[pos.len - 1];
    const srcs = pos[0 .. pos.len - 1];

    const dst_is_dir = isDirectory(dst);
    if (srcs.len > 1 and !dst_is_dir) {
        common.printError("cp: destination must be an existing directory when copying multiple sources", .{});
        return error.InvalidArgs;
    }

    for (srcs) |src| {
        const final_dst = try computeFinalDst(allocator, src, dst, dst_is_dir or srcs.len > 1);
        defer allocator.free(final_dst);
        try copyPath(allocator, src, final_dst, opts);
    }
}

pub fn copyPath(allocator: std.mem.Allocator, src: []const u8, dst: []const u8, opts: Options) anyerror!void {
    const cwd = std.fs.cwd();
    const src_stat = try cwd.statFile(src);

    if (src_stat.kind == .directory) {
        if (!opts.recursive) return error.IsDir;
        try copyDirRecursive(allocator, src, dst, opts);
        return;
    }

    try copyFileWithProgress(src, dst, opts.force, "cp");
}

fn copyDirRecursive(allocator: std.mem.Allocator, src: []const u8, dst: []const u8, opts: Options) anyerror!void {
    const cwd = std.fs.cwd();

    cwd.makePath(dst) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var dir = try cwd.openDir(src, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const child_src = try std.fs.path.join(allocator, &.{ src, entry.name });
        defer allocator.free(child_src);
        const child_dst = try std.fs.path.join(allocator, &.{ dst, entry.name });
        defer allocator.free(child_dst);

        if (entry.kind == .directory) {
            try copyDirRecursive(allocator, child_src, child_dst, opts);
        } else if (entry.kind == .file) {
            try copyFileWithProgress(child_src, child_dst, opts.force, "cp");
        }
    }
}

pub fn copyFileWithProgress(src: []const u8, dst: []const u8, force: bool, label: []const u8) anyerror!void {
    const cwd = std.fs.cwd();

    var src_file = try cwd.openFile(src, .{});
    defer src_file.close();

    const src_stat = try src_file.stat();
    const total = src_stat.size;

    const create_flags = std.fs.File.CreateFlags{
        .truncate = true,
        .exclusive = !force,
        .read = true,
    };

    var dst_file = try cwd.createFile(dst, create_flags);
    defer dst_file.close();

    var buf: [64 * 1024]u8 = undefined;
    var copied: u64 = 0;

    while (true) {
        const n = try src_file.read(&buf);
        if (n == 0) break;
        try dst_file.writeAll(buf[0..n]);
        copied += n;
        try common.renderProgress(label, src, copied, total);
    }

    try common.finishProgress();
}

fn computeFinalDst(allocator: std.mem.Allocator, src: []const u8, dst: []const u8, force_dir_mode: bool) ![]u8 {
    if (force_dir_mode) {
        return std.fs.path.join(allocator, &.{ dst, std.fs.path.basename(src) });
    }

    if (isDirectory(dst)) {
        return std.fs.path.join(allocator, &.{ dst, std.fs.path.basename(src) });
    }

    return allocator.dupe(u8, dst);
}

fn isDirectory(path: []const u8) bool {
    const st = std.fs.cwd().statFile(path) catch return false;
    return st.kind == .directory;
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox cp [flags] <src...> <dst>\n\n" ++
            "Copy files and directories.\n\n" ++
            "Flags:\n" ++
            "  -r, --recursive      Copy directories recursively\n" ++
            "  -f, --force          Overwrite destination\n" ++
            "      --help           Show this help\n\n" ++
            "Examples:\n" ++
            "  zigbox cp a.txt b.txt\n" ++
            "  zigbox cp a.txt b.txt dir/\n" ++
            "  zigbox cp -r src_dir dst_dir\n",
    ) catch {};
}
