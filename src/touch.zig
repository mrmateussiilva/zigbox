const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-c, --no-create      Do not create any files.
        \\<str>...             Files to touch.
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

    const paths = parsed.positionals[0];
    if (paths.len == 0) {
        common.printError("touch: missing file operand", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const no_create = parsed.args.@"no-create" != 0;
    for (paths) |path| {
        var file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => {
                if (no_create) continue;
                var created = std.fs.cwd().createFile(path, .{ .truncate = false, .read = true }) catch |create_err| {
                    common.printError("touch: {s}: {s}", .{ path, @errorName(create_err) });
                    return create_err;
                };
                created.close();
                continue;
            },
            else => {
                common.printError("touch: {s}: {s}", .{ path, @errorName(err) });
                return err;
            },
        };
        defer file.close();

        // Write nothing, just ensure file is opened in write mode.
        try file.seekTo(0);
    }
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox touch [flags] <file>...\n\n" ++
            "Create empty files if missing.\n\n" ++
            "Flags:\n" ++
            "  -c, --no-create     Do not create missing files\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
