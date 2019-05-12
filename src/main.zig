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
    var underlying_allocator = std.heap.c_allocator;

    var arena = std.heap.ArenaAllocator.init(underlying_allocator);
    errdefer arena.deinit();

    var allocator = &arena.allocator;
    var args_it = os.args();

    // skip args[0]

    _ = args_it.skip();

    const host = try (args_it.next(allocator) orelse {
        std.debug.warn("no host provided\n");
        return error.InvalidArgs;
    });

    const remote_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no remote path provided\n");
        return error.InvalidArgs;
    });

    const output_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no path provided\n");
        return error.InvalidArgs;
    });

    std.debug.warn("host: {} remote: {} output path: {}\n", host, remote_path, output_path);

    var sockfd = try std.os.posixSocket(std.os.linux.AF_INET, std.os.linux.SOCK_STREAM, 0);
    std.debug.warn("sock fd: {}\n", sockfd);

    var ip4addr = try std.net.parseIp4(host);
    var addr = std.net.Address.initIp4(ip4addr, 80);
    const const_addr = &addr.os_addr;
    try std.os.posixConnect(sockfd, const_addr);

    var buffer: [256]u8 = undefined;
    const base_http = "GET {} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n\r\n";
    var msg = try std.fmt.bufPrint(&buffer, base_http, remote_path, host);

    try std.os.posixWrite(sockfd, msg);

    // TODO: read more
    var buf: [1024]u8 = undefined;
    var read_bytes = try std.os.posixRead(sockfd, &buf);

    std.debug.warn("read {} bytes\n", read_bytes);
    std.debug.warn("buf = '{}'\n", buf);
}
