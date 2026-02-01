const std = @import("std");

const MemHandler = struct {
    base: u64,
    size: u64,
    handler: *anyopaque,

    read: fn (handler: *anyopaque, addr: u64, size: u64) u64,
    write: fn (handler: *anyopaque, addr: u64, val: u64) u64,
};

const MemBus = struct {
    handlers: std.ArrayList(MemHandler),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) MemBus {
        return .{
            .handlers = .empty,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *MemBus) void {
        self.handlers.deinit(self.alloc);
    }

    pub fn register(self: *MemBus, handler: MemHandler) !void {
        try self.handlers.append(self.alloc, handler);
    }

    fn getHandler(self: *MemBus, addr: u64) ?*MemHandler {
        for (self.handlers) |*h| {
            if (addr >= h.base and addr < h.base + h.size)
                return h;
        }

        return null;
    }
};
