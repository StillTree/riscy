const std = @import("std");
const riscv = @import("riscv_core");

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    var ram = try riscv.Ram.init(arena.allocator(), 16384);
    defer ram.deinit();

    var state = riscv.CpuState.init(arena.allocator());

    try state.mem_bus.register(ram.memHandler(0x80000000));

    const file = try std.fs.cwd().readFileAlloc(arena.allocator(), "../riscv-tests/isa/rv64ui-p-addi", 10320);
    std.debug.print("{d}\n", .{file.len});

    if (!std.mem.eql(u8, file[0..4], &[_]u8{ 0x7f, 'E', 'L', 'F' })) {
        std.debug.print("Invalid ELF!!!\n", .{});
    }

    const elf_header: *std.elf.Elf64_Ehdr = @ptrCast(@alignCast(file.ptr));

    const prog_headers_ptr: [*]std.elf.Elf64_Phdr = @ptrFromInt(@intFromPtr(file.ptr) + elf_header.e_phoff);
    const prog_headers = prog_headers_ptr[0..elf_header.e_phnum];

    for (prog_headers) |prog_header| {
        if (prog_header.p_type != std.elf.PT_LOAD)
            continue;

        const section_ptr: [*]u8 = @ptrFromInt(@intFromPtr(file.ptr) + prog_header.p_offset);
        const addr = prog_header.p_vaddr;

        // @memset(state.mem[addr..(addr + prog_header.p_memsz)], 0);
        for (addr..(addr + prog_header.p_memsz)) |i| {
            try state.mem_bus.store(u8, i, 0);
        }
        // @memcpy(state.mem[addr..(addr + prog_header.p_filesz)], section_ptr[0..prog_header.p_filesz]);
        for (addr..(addr + prog_header.p_filesz)) |i| {
            try state.mem_bus.store(u8, i, section_ptr[i - addr]);
        }
    }

    state.pc = elf_header.e_entry;

    for (0..100) |i| {
        try state.step();
        std.debug.print("{d} ", .{i});
    }

    state.printRegisters();

    // const prog = comptime block: {
    //     const addi = a.assemble("addi x5, x0, 10");
    //     const addi2 = a.assemble("addi x6, x0, 3");
    //     const add = a.assemble("add x7, x5, x6");
    //     const jal = a.assemble("jal x0, 4");
    //     const add2 = a.assemble("add x7, x7, x6");

    //     break :block addi ++ addi2 ++ add ++ jal ++ add2;
    // };
}
