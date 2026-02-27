const std = @import("std");

const common = @import("common.zig");
const ls_cmd = @import("ls.zig");
const rm_cmd = @import("rm.zig");
const find_cmd = @import("find.zig");
const grep_cmd = @import("grep.zig");
const cat_cmd = @import("cat.zig");
const mkdir_cmd = @import("mkdir.zig");
const touch_cmd = @import("touch.zig");
const pwd_cmd = @import("pwd.zig");
const echo_cmd = @import("echo.zig");
const cp_cmd = @import("cp.zig");
const mv_cmd = @import("mv.zig");

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

    if (std.mem.eql(u8, subcommand, "cat")) {
        cat_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("cat failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "mkdir")) {
        mkdir_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("mkdir failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "touch")) {
        touch_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("touch failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "pwd")) {
        pwd_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("pwd failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "echo")) {
        echo_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("echo failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "cp")) {
        cp_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("cp failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    if (std.mem.eql(u8, subcommand, "mv")) {
        mv_cmd.run(allocator, sub_args) catch |err| {
            if (err == error.InvalidArgs) return;
            common.printError("mv failed: {s}", .{@errorName(err)});
            return err;
        };
        return;
    }

    common.printError("unknown subcommand: '{s}'", .{subcommand});
    common.printRootHelp();
    return error.InvalidArgs;
}
