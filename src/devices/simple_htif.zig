const std = @import("std");
const mem = @import("../mem_bus.zig");

pub const SimpleHtif = struct {
    to_host: u64,

    pub fn init() SimpleHtif {
        return .{
            .to_host = 0,
        };
    }

    pub fn load8(ptr: *anyopaque, addr: u64) u8 {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        _ = addr;

        return @truncate(self.to_host);
    }

    pub fn load16(ptr: *anyopaque, addr: u64) u16 {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 6)
            std.debug.print("SimpleHtif.load16 unexpected address: {}\n", .{addr});

        return @truncate(self.to_host);
    }

    pub fn load32(ptr: *anyopaque, addr: u64) u32 {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 4)
            std.debug.print("SimpleHtif.load32 unexpected address: {}\n", .{addr});

        return @truncate(self.to_host);
    }

    pub fn load64(ptr: *anyopaque, addr: u64) u64 {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 0)
            std.debug.print("SimpleHtif.load64 unexpected address: {}\n", .{addr});

        return self.to_host;
    }

    pub fn store8(ptr: *anyopaque, addr: u64, val: u8) void {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        _ = addr;

        self.to_host = val;

        std.debug.print("store8 tohost: {}\n", .{val});
    }

    pub fn store16(ptr: *anyopaque, addr: u64, val: u16) void {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 6)
            std.debug.print("SimpleHtif.store16 unexpected address: {}\n", .{addr});

        self.to_host = val;

        std.debug.print("store16 tohost: {}\n", .{val});
    }

    pub fn store32(ptr: *anyopaque, addr: u64, val: u32) void {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 4)
            std.debug.print("SimpleHtif.store32 unexpected address: {}\n", .{addr});

        self.to_host = val;

        std.debug.print("store32 tohost: {}\n", .{val});
    }

    pub fn store64(ptr: *anyopaque, addr: u64, val: u64) void {
        const self: *SimpleHtif = @ptrCast(@alignCast(ptr));
        if (addr > 0)
            std.debug.print("SimpleHtif.store64 unexpected address: {}\n", .{addr});

        self.to_host = val;

        std.debug.print("store64 tohost: {}\n", .{val});
    }

    pub fn memHandler(self: *SimpleHtif, start: u64) mem.Handler {
        return .{
            .ptr = self,
            .vtable = &.{
                .load8 = load8,
                .load16 = load16,
                .load32 = load32,
                .load64 = load64,
                .store8 = store8,
                .store16 = store16,
                .store32 = store32,
                .store64 = store64,
            },
            .start = start,
            .end = start + 8,
        };
    }
};
