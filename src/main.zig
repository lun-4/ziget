const std = @import("std");
const os = std.os;

const c = @cImport({
    @cInclude("sys/types.h");
    @cInclude("sys/socket.h");
    @cInclude("netinet/in.h");
    @cInclude("arpa/inet.h");
    @cInclude("stdio.h");
});

const ZigetError = error{
    CreateSockFail,
    InvalidAddr,
    ConnectError,
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

    // for some reason c.SOCK_STREAM doesn't work because of typing
    var sock = c.socket(c.AF_INET, 2, 0);
    if (sock < 0) {
        std.debug.warn("failed to create socket\n");
        return ZigetError.CreateSockFail;
    }

    std.debug.warn("sock fd: {}\n", sock);

    // make addr struct
    var addr: c.struct_sockaddr_in = undefined;

    addr.sin_family = c.AF_INET;
    addr.sin_port = c.htons(80);

    var host_c: [*c]const u8 = @ptrCast([*c]const u8, &host);

    _ = c.printf(c"host_c from c: '%s'\n", host_c);

    if (c.inet_pton(c.AF_INET, host_c, &addr.sin_addr) <= 0) {
        return ZigetError.InvalidAddr;
    }

    var addr_c: [*c]const c.struct_sockaddr = @ptrCast([*c]const c.struct_sockaddr, &addr);

    if (c.connect(sock, addr_c, @sizeOf(c.struct_sockaddr_in)) < 0) {
        return ZigetError.ConnectError;
    }

    std.debug.warn("owo???\n");
}
