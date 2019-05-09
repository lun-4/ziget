const std = @import("std");
const os = std.os;

pub fn main() anyerror!void {
    var da = std.heap.DirectAllocator.init();
    var arena = std.heap.ArenaAllocator.init(&da.allocator);
    errdefer arena.deinit();

    var allocator = &arena.allocator;
    var args_it = os.args();

    // skip args[0]

    _ = args_it.skip(allocator);

    const url = try (args_it.next(allocator) orelse {
        std.debug.warn("no url provided");
        return error.InvalidArgs;
    });
}
