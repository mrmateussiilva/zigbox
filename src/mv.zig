const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");
const cp = @import("cp.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help                Show this help message.
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
        common.printError("mv: expected <src...> <dst>", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const dst = pos[pos.len - 1];
    const srcs = pos[0 .. pos.len - 1];
    const force = parsed.args.force != 0;

    const dst_is_dir = isDirectory(dst);
    if (srcs.len > 1 and !dst_is_dir) {
        common.printError("mv: destination must be an existing directory when moving multiple sources", .{});
        return error.InvalidArgs;
    }

    for (srcs) |src| {
        const final_dst = try computeFinalDst(allocator, src, dst, dst_is_dir or srcs.len > 1);
        defer allocator.free(final_dst);
        try moveOne(allocator, src, final_dst, force);
    }
}

fn moveOne(allocator: std.mem.Allocator, src: []const u8, dst: []const u8, force: bool) anyerror!void {
    const cwd = std.fs.cwd();

    if (force) {
        cwd.deleteFile(dst) catch {};
    }

    cwd.rename(src, dst) catch |err| switch (err) {
        error.RenameAcrossMountPoints => {
            const src_stat = try cwd.statFile(src);
            if (src_stat.kind == .directory) {
                try cp.copyPath(allocator, src, dst, .{ .recursive = true, .force = force });
                try cwd.deleteTree(src);
            } else {
                try cp.copyFileWithProgress(src, dst, force, "mv");
                try cwd.deleteFile(src);
            }
        },
        else => return err,
    };
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
        "Usage: zigbox mv [flags] <src...> <dst>\n\n" ++
            "Move/rename files and directories.\n\n" ++
            "Flags:\n" ++
            "  -f, --force          Overwrite destination\n" ++
            "      --help           Show this help\n\n" ++
            "Examples:\n" ++
            "  zigbox mv a.txt b.txt\n" ++
            "  zigbox mv a.txt b.txt dir/\n",
    ) catch {};
}
