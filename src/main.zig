const std = @import("std");

const common = @import("common.zig");
const ls_cmd = @import("ls.zig");
const rm_cmd = @import("rm.zig");
const find_cmd = @import("find.zig");
const grep_cmd = @import("grep.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            common.printError("memory leak(s) detected", .{});
        }
    }
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    if (argv.len <= 1) {
        common.printRootHelp();
        return;
    }

    const subcommand = argv[1];
    if (std.mem.eql(u8, subcommand, "-h") or std.mem.eql(u8, subcommand, "--help")) {
        common.printRootHelp();
        return;
    }

    const sub_args = argv[2..];

    if (std.mem.eql(u8, subcommand, "ls")) {
        ls_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("ls failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "rm")) {
        rm_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("rm failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "find")) {
        find_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("find failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "grep")) {
        grep_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("grep failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    common.printError("unknown subcommand: '{s}'", .{subcommand});
    common.printRootHelp();
    return error.InvalidArgs;
}
