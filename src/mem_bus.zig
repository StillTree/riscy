const std = @import("std");

/// MemHandlers must outlive the memory bus.
pub const Handler = struct {
    base: u64,
    size: u64,
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
    cache: [CACHE_LEN]CacheEntry,

    const CACHE_LEN = 1024;
    const CACHE_MASK = CACHE_LEN - 1;

    const CacheEntry = struct {
        pfn: u64,
        handlerIndex: usize,
    };

    pub fn init(alloc: std.mem.Allocator) Bus {
        return .{
            .handlers = .empty,
            .alloc = alloc,
            .cache = [_]CacheEntry{.{ .pfn = std.math.maxInt(u64), .handlerIndex = std.math.maxInt(usize) }} ** CACHE_LEN,
        };
    }

    pub fn deinit(self: *Bus) void {
        self.handlers.deinit(self.alloc);
    }

    pub fn register(self: *Bus, handler: Handler) !void {
        for (self.handlers.items) |*h| {
            if (handler.base < h.base + h.size and handler.base + handler.size > h.base) {
                return error.MemHandlerOverlap;
            }
        }

        try self.handlers.append(self.alloc, handler);
    }

    // pub fn load8(self: *Bus, addr: u64) !u8 {
    //     const handler = try self.getHandler(addr);

    //     return try handler.load8(addr - handler.base);
    // }

    // pub fn load16(self: *Bus, addr: u64) !u16 {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 2)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 2 != 0)
    //         return error.UnalignedMemAccess;

    //     return try handler.load16(addr - handler.base);
    // }

    // pub fn load32(self: *Bus, addr: u64) !u32 {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 4)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 4 != 0)
    //         return error.UnalignedMemAccess;

    //     return try handler.load32(addr - handler.base);
    // }

    // pub fn load64(self: *Bus, addr: u64) !u64 {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 8)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 8 != 0)
    //         return error.UnalignedMemAccess;

    //     return try handler.load64(addr - handler.base);
    // }

    pub fn load(self: *Bus, comptime T: type, addr: u64) !T {
        const handler = try self.getHandler(addr);
        const size = @sizeOf(T);

        if (addr > handler.base + handler.size - size)
            return error.CrossBoundryMemAccess;
        if (addr % size != 0)
            return error.UnalignedMemAccess;

        return switch (T) {
            u8 => handler.load8(addr - handler.base),
            u16 => handler.load16(addr - handler.base),
            u32 => handler.load32(addr - handler.base),
            u64 => handler.load64(addr - handler.base),
            else => @compileError("Unsupported type"),
        };
    }

    // pub fn store8(self: *Bus, addr: u64, val: u8) !void {
    //     const handler = try self.getHandler(addr);

    //     try handler.store8(addr - handler.base, val);
    // }

    // pub fn store16(self: *Bus, addr: u64, val: u16) !void {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 2)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 2 != 0)
    //         return error.UnalignedMemAccess;

    //     try handler.store16(addr - handler.base, val);
    // }

    // pub fn store32(self: *Bus, addr: u64, val: u32) !void {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 4)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 4 != 0)
    //         return error.UnalignedMemAccess;

    //     try handler.store32(addr - handler.base, val);
    // }

    // pub fn store64(self: *Bus, addr: u64, val: u64) !void {
    //     const handler = try self.getHandler(addr);

    //     if (addr > handler.base + handler.size - 8)
    //         return error.CrossBoundryMemAccess;
    //     if (addr % 8 != 0)
    //         return error.UnalignedMemAccess;

    //     try handler.store64(addr - handler.base, val);
    // }

    pub fn store(self: *Bus, comptime T: type, addr: u64, val: T) !void {
        const handler = try self.getHandler(addr);
        const size = @sizeOf(T);

        if (addr > handler.base + handler.size - size)
            return error.CrossBoundryMemAccess;
        if (addr % size != 0)
            return error.UnalignedMemAccess;

        switch (T) {
            u8 => handler.store8(addr - handler.base, val),
            u16 => handler.store16(addr - handler.base, val),
            u32 => handler.store32(addr - handler.base, val),
            u64 => handler.store64(addr - handler.base, val),
            else => @compileError("Unsupported type"),
        }
    }

    fn getHandler(self: *Bus, addr: u64) !*Handler {
        const pfn = addr >> 12;
        const masked_pfn = pfn & CACHE_MASK;

        if (self.cache[masked_pfn].pfn == pfn) {
            const i = self.cache[masked_pfn].handlerIndex;
            // In theory this should always be true
            std.debug.assert(i < self.handlers.items.len);
            return &self.handlers.items[i];
        }

        for (self.handlers.items, 0..) |*h, i| {
            if (addr >= h.base and addr < h.base + h.size) {
                self.cache[masked_pfn].handlerIndex = i;
                self.cache[masked_pfn].pfn = pfn;

                return h;
            }
        }

        return error.NoHandlerInMemRegion;
    }
};
