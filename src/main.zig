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
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();

    var allocator = &arena.allocator;
    var args_it = std.process.args();

    // skip args[0]

    _ = args_it.skip();

    const host = try (args_it.next(allocator) orelse {
        std.debug.warn("no host provided\n", .{});
        return error.InvalidArgs;
    });

    const remote_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no remote path provided\n", .{});
        return error.InvalidArgs;
    });

    const output_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no path provided\n", .{});
        return error.InvalidArgs;
    });

    std.debug.warn("host: {} remote: {} output path: {}\n", .{ host, remote_path, output_path });

    var sockfd = try os.socket(os.linux.AF_INET, os.linux.SOCK_STREAM, 0);
    defer os.close(sockfd);

    // TODO: find a way to call gethostbyname() or some other way to DNS,
    // prefferably without libc
    var addr = try std.net.Address.parseIp(host, 80);
    var conn = try std.net.tcpConnectToAddress(addr);
    defer conn.close();

    var buffer: [256]u8 = undefined;
    const base_http = "GET {} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n\r\n";
    var msg = try std.fmt.bufPrint(&buffer, base_http, .{ remote_path, host });

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

    std.debug.warn("written {} bytes to file '{}'\n", .{ total_bytes, output_path });
}
