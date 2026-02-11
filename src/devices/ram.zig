const std = @import("std");
const mem = @import("../mem_bus.zig");

pub const Ram = struct {
    mem: []u8,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, size: u64) !Ram {
        const memory = try alloc.alloc(u8, size);

        return .{
            .mem = memory,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Ram) void {
        self.alloc.free(self.mem);
    }

    pub fn load8(ptr: *anyopaque, addr: u64) u8 {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        return self.mem[addr];
    }

    pub fn load16(ptr: *anyopaque, addr: u64) u16 {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        return std.mem.readInt(u16, self.mem[addr..][0..2], .little);
    }

    pub fn load32(ptr: *anyopaque, addr: u64) u32 {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        return std.mem.readInt(u32, self.mem[addr..][0..4], .little);
    }

    pub fn load64(ptr: *anyopaque, addr: u64) u64 {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        return std.mem.readInt(u64, self.mem[addr..][0..8], .little);
    }

    pub fn store8(ptr: *anyopaque, addr: u64, val: u8) void {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        self.mem[addr] = val;
    }

    pub fn store16(ptr: *anyopaque, addr: u64, val: u16) void {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        std.mem.writeInt(u16, self.mem[addr..][0..2], val, .little);
    }

    pub fn store32(ptr: *anyopaque, addr: u64, val: u32) void {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        std.mem.writeInt(u32, self.mem[addr..][0..4], val, .little);
    }

    pub fn store64(ptr: *anyopaque, addr: u64, val: u64) void {
        const self: *Ram = @ptrCast(@alignCast(ptr));

        std.mem.writeInt(u64, self.mem[addr..][0..8], val, .little);
    }

    pub fn memHandler(self: *Ram, base: u64) mem.Handler {
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
            .base = base,
            .size = self.mem.len,
        };
    }
};
