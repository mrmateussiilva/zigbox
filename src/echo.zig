const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help               Show this help message.
        \\-n                    Do not output the trailing newline.
        \\<str>...             Text to print.
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

    const parts = parsed.positionals[0];
    const out = common.stdoutFile();

    var i: usize = 0;
    while (i < parts.len) : (i += 1) {
        if (i != 0) try out.writeAll(" ");
        try out.writeAll(parts[i]);
    }

    if (parsed.args.n == 0) {
        try out.writeAll("\n");
    }
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox echo [flags] [text...]\n\n" ++
            "Print text to stdout.\n\n" ++
            "Flags:\n" ++
            "  -n                  No trailing newline\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
