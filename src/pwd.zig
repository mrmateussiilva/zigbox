const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-L, --logical        Use PWD from environment when available (default).
        \\-P, --physical       Resolve symlinks and print physical path.
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

    if (parsed.args.logical != 0 and parsed.args.physical != 0) {
        common.printError("pwd: options -L and -P are mutually exclusive", .{});
        return error.InvalidArgs;
    }

    if (parsed.args.physical != 0) {
        const p = try std.fs.cwd().realpathAlloc(arena, ".");
        try common.writeFmt(common.stdoutFile(), "{s}\n", .{p});
        return;
    }

    if (std.process.getEnvVarOwned(arena, "PWD")) |pwd_env| {
        if (std.fs.path.isAbsolute(pwd_env)) {
            try common.writeFmt(common.stdoutFile(), "{s}\n", .{pwd_env});
            return;
        }
    } else |_| {}

    const cwd = try std.process.getCwdAlloc(arena);
    try common.writeFmt(common.stdoutFile(), "{s}\n", .{cwd});
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox pwd [flags]\n\n" ++
            "Print current working directory.\n\n" ++
            "Flags:\n" ++
            "  -L, --logical        Use PWD (default)\n" ++
            "  -P, --physical       Resolve symlinks\n" ++
            "      --help           Show this help\n",
    ) catch {};
}
