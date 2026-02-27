const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-p, --parents        No error if existing, make parent directories as needed.
        \\<str>...             Directories to create.
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
        common.printError("mkdir: missing operand", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const make_parents = parsed.args.parents != 0;
    for (paths) |path| {
        if (make_parents) {
            std.fs.cwd().makePath(path) catch |err| {
                common.printError("mkdir: {s}: {s}", .{ path, @errorName(err) });
                return err;
            };
        } else {
            std.fs.cwd().makeDir(path) catch |err| {
                common.printError("mkdir: {s}: {s}", .{ path, @errorName(err) });
                return err;
            };
        }
    }
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox mkdir [flags] <dir>...\n\n" ++
            "Create directories.\n\n" ++
            "Flags:\n" ++
            "  -p, --parents       Create parents and ignore existing dirs\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
