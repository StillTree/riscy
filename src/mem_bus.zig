const std = @import("std");

/// MemHandlers must outlive the memory bus.
pub const Handler = struct {
    /// Inclusive.
    start: u64,
    /// Exclusive.
    end: u64,
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        load8: *const fn (ptr: *anyopaque, addr: u64) u8,
        load16: *const fn (ptr: *anyopaque, addr: u64) u16,
        load32: *const fn (ptr: *anyopaque, addr: u64) u32,
        load64: *const fn (ptr: *anyopaque, addr: u64) u64,

        store8: *const fn (ptr: *anyopaque, addr: u64, val: u8) void,
        store16: *const fn (ptr: *anyopaque, addr: u64, val: u16) void,
        store32: *const fn (ptr: *anyopaque, addr: u64, val: u32) void,
        store64: *const fn (ptr: *anyopaque, addr: u64, val: u64) void,
    };

    pub fn load8(self: *Handler, addr: u64) u8 {
        return self.vtable.load8(self.ptr, addr);
    }

    pub fn load16(self: *Handler, addr: u64) u16 {
        return self.vtable.load16(self.ptr, addr);
    }

    pub fn load32(self: *Handler, addr: u64) u32 {
        return self.vtable.load32(self.ptr, addr);
    }

    pub fn load64(self: *Handler, addr: u64) u64 {
        return self.vtable.load64(self.ptr, addr);
    }

    pub fn store8(self: *Handler, addr: u64, val: u8) void {
        self.vtable.store8(self.ptr, addr, val);
    }

    pub fn store16(self: *Handler, addr: u64, val: u16) void {
        self.vtable.store16(self.ptr, addr, val);
    }

    pub fn store32(self: *Handler, addr: u64, val: u32) void {
        self.vtable.store32(self.ptr, addr, val);
    }

    pub fn store64(self: *Handler, addr: u64, val: u64) void {
        self.vtable.store64(self.ptr, addr, val);
    }
};

pub const Bus = struct {
    handlers: std.ArrayList(Handler),
    alloc: std.mem.Allocator,

    // TODO: Consider changing it so RAM is the default and there is some sort of a fast path for it,
    // the devices will function the same way

    pub fn init(alloc: std.mem.Allocator) Bus {
        return .{
            .handlers = .empty,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Bus) void {
        self.handlers.deinit(self.alloc);
    }

    /// Every registration needs to be strictly in order.
    pub fn register(self: *Bus, handler: Handler) !void {
        const lastHandler = self.handlers.getLastOrNull();

        if (lastHandler) |h| {
            if (handler.start < h.end) {
                return error.MemHandlerOverlap;
            }
        }

        try self.handlers.append(self.alloc, handler);
    }

    pub fn load(self: *Bus, comptime T: type, addr: u64) !T {
        const handler = try self.getHandler(addr);
        const size = @sizeOf(T);

        if (addr > handler.end - size)
            return error.CrossBoundryMemAccess;
        if (addr % size != 0)
            return error.UnalignedMemAccess;

        return switch (T) {
            u8 => handler.load8(addr - handler.start),
            u16 => handler.load16(addr - handler.start),
            u32 => handler.load32(addr - handler.start),
            u64 => handler.load64(addr - handler.start),
            else => @compileError("Unsupported type"),
        };
    }

    pub fn store(self: *Bus, comptime T: type, addr: u64, val: T) !void {
        const handler = try self.getHandler(addr);
        const size = @sizeOf(T);

        if (addr > handler.end - size)
            return error.CrossBoundryMemAccess;
        if (addr % size != 0)
            return error.UnalignedMemAccess;

        switch (T) {
            u8 => handler.store8(addr - handler.start, val),
            u16 => handler.store16(addr - handler.start, val),
            u32 => handler.store32(addr - handler.start, val),
            u64 => handler.store64(addr - handler.start, val),
            else => @compileError("Unsupported type"),
        }
    }

    fn getHandler(self: *Bus, addr: u64) !*Handler {
        var left: usize = 0;
        var right: usize = self.handlers.items.len;

        while (left < right) {
            const mid = left + (right - left) / 2;
            const h = &self.handlers.items[mid];

            if (addr < h.start) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        if (left == 0)
            return error.NoHandlerInMemRegion;

        const candidate = &self.handlers.items[left - 1];

        if (addr >= candidate.end)
            return error.NoHandlerInMemRegion;

        return candidate;
    }
};
