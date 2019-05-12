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

    var sockfd = try os.posixSocket(os.linux.AF_INET, os.linux.SOCK_STREAM, 0);

    // TODO: find a way to call gethostbyname() or some other way to DNS,
    // prefferably without libc
    var ip4addr = try std.net.parseIp4(host);

    // NOTE: no https support, hopefully by 0.5.0 we have something.
    var addr = std.net.Address.initIp4(ip4addr, 80);
    const const_addr = &addr.os_addr;
    try os.posixConnect(sockfd, const_addr);

    var buffer: [256]u8 = undefined;
    const base_http = "GET {} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n\r\n";
    var msg = try std.fmt.bufPrint(&buffer, base_http, remote_path, host);

    try os.posixWrite(sockfd, msg);

    var buf: [1024]u8 = undefined;
    var byte_count: usize = 0;
    var total_bytes: usize = 0;

    var file = try os.File.openWrite(output_path);

    while (true) {
        byte_count = try std.os.posixRead(sockfd, &buf);
        if (byte_count == 0) break;

        try file.write(buf);
        total_bytes += byte_count;
    }

    std.debug.warn("written {} bytes to file '{}'\n", total_bytes, output_path);
}
