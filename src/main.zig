const std = @import("std");
const os = std.os;

const ZigetError = error{
    CreateSockFail,
    InvalidAddr,
    ConnectError,
    SendError,
    RecvError,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    // skip args[0]

    _ = args_it.skip();

    const host = (args_it.next() orelse {
        std.debug.print("no host provided\n", .{});
        return error.InvalidArgs;
    });

    const remote_path = (args_it.next() orelse {
        std.debug.print("no remote path provided\n", .{});
        return error.InvalidArgs;
    });

    const output_path = (args_it.next() orelse {
        std.debug.print("no path provided\n", .{});
        return error.InvalidArgs;
    });

    std.debug.print("host: {s} remote: {s} output path: {s}\n", .{ host, remote_path, output_path });

    var conn = try std.net.tcpConnectToHost(allocator, host, 80);
    defer conn.close();

    var buffer: [256]u8 = undefined;
    const base_http = "GET {s} HTTP/1.1\r\nHost: {s}\r\nConnection: close\r\n\r\n";
    const msg = try std.fmt.bufPrint(&buffer, base_http, .{ remote_path, host });

    _ = try conn.write(msg);

    var buf: [1024]u8 = undefined;
    var total_bytes: usize = 0;

    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    while (true) {
        const byte_count = try conn.read(&buf);
        if (byte_count == 0) break;

        _ = try file.write(&buf);
        total_bytes += byte_count;
    }

    std.debug.print("written {d} bytes to file '{s}'\n", .{ total_bytes, output_path });
}
