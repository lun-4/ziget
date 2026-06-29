const std = @import("std");
const net = std.Io.net;

pub fn main(init: std.process.Init) anyerror!void {
    const allocator = init.gpa;
    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
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

    const host_name = try net.HostName.init(host);
    var conn = try net.HostName.connect(host_name, init.io, 80, .{
        .mode = .stream,
        .protocol = .tcp,
    });
    defer conn.close(init.io);

    var buffer: [256]u8 = undefined;
    const base_http = "GET {s} HTTP/1.1\r\nHost: {s}\r\nConnection: close\r\n\r\n";
    const msg = try std.fmt.bufPrint(&buffer, base_http, .{ remote_path, host });

    var conn_write_buf: [1024]u8 = undefined;
    var conn_writer = conn.writer(init.io, &conn_write_buf);
    try conn_writer.interface.writeAll(msg);
    try conn_writer.interface.flush();

    var file = try std.Io.Dir.cwd().createFile(init.io, output_path, .{});
    defer file.close(init.io);

    var conn_read_buf: [1024]u8 = undefined;
    var conn_reader = conn.reader(init.io, &conn_read_buf);
    var file_write_buf: [1024]u8 = undefined;
    var file_writer = file.writerStreaming(init.io, &file_write_buf);
    const total_bytes = try conn_reader.interface.streamRemaining(&file_writer.interface);
    try file_writer.interface.flush();

    std.debug.print("written {d} bytes to file '{s}'\n", .{ total_bytes, output_path });
}
