const std = @import("std");
const clap = @import("clap");

const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const params = comptime clap.parseParamsComptime(
        \\--help          Show this help message.
        \\<str>...        Files to print.
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
        common.printError("cat: missing file operand", .{});
        printHelp();
        return error.InvalidArgs;
    }

    const out = common.stdoutFile();
    var buf: [8192]u8 = undefined;

    for (paths) |path| {
        var file = std.fs.cwd().openFile(path, .{}) catch |err| {
            common.printError("cat: {s}: {s}", .{ path, @errorName(err) });
            continue;
        };
        defer file.close();

        while (true) {
            const n = try file.read(&buf);
            if (n == 0) break;
            try out.writeAll(buf[0..n]);
        }
    }
}

fn printHelp() void {
    common.stdoutFile().writeAll(
        "Usage: zigbox cat [flags] <path>...\n\n" ++
            "Print file contents to stdout.\n\n" ++
            "Flags:\n" ++
            "      --help          Show this help\n",
    ) catch {};
}
