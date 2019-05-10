const std = @import("std");
const os = std.os;

const c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/socket.h");
    @cInclude("netinet/in.h");
    @cInclude("arpa/inet.h");
    @cInclude("netdb.h");
    @cInclude("stdio.h");
});

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

    //var sock = std.os.linux.socket(std.os.linux.AF_INET, std.os.linux.SOCK_STREAM, 0);
    var sock = c.socket(c.AF_INET, std.os.linux.SOCK_STREAM, 0);
    if (sock < 0) {
        std.debug.warn("failed to create socket\n");
        return ZigetError.CreateSockFail;
    }

    std.debug.warn("sock fd: {}\n", sock);

    var addr: c.struct_sockaddr_in = undefined;

    // TODO: convert given host to cstr
    var host_c = c"1.1.1.1";

    _ = c.printf(c"host_c = '%s'\n", host_c);

    if (c.inet_pton(std.os.linux.AF_INET, host_c, &addr.sin_addr) <= 0) {
        return ZigetError.InvalidAddr;
    }

    if (std.os.linux.connect(sock, &addr, @sizeOf(c.struct_sockaddr_in)) < 0) {
        return ZigetError.ConnectError;
    }

    //const msg = c"HTTP/1.0 GET /\r\n\r\n";
    var msg = c"HTTP/1.0 GET /\r\n\r\n";

    if (c.write(sock, msg, 255) < 0) {
        return ZigetError.SendError;
    }

    var buf: [255]u8 = undefined;

    if (std.os.linux.read(sock, &buf, 255) < 0) {
        return ZigetError.RecvError;
    }

    std.debug.warn("buf = '{}'\n", buf);
}
