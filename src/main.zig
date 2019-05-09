const std = @import("std");
const os = std.os;

pub fn main() anyerror!void {
    var underlying_allocator = std.heap.c_allocator;

    var arena = std.heap.ArenaAllocator.init(underlying_allocator);
    errdefer arena.deinit();

    var allocator = &arena.allocator;
    var args_it = os.args();

    // skip args[0]

    _ = args_it.skip();

    const url = try (args_it.next(allocator) orelse {
        std.debug.warn("no url provided\n");
        return error.InvalidArgs;
    });

    // TODO: do parsing of url to give it as default for output path

    const path = try (args_it.next(allocator) orelse {
        std.debug.warn("no path provided\n");
        return error.InvalidArgs;
    });

    std.debug.warn("url: {} output path: {}\n", url, path);
}
