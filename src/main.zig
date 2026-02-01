const std = @import("std");
const riscv = @import("riscv_core");

pub fn main() !void {
    const offset = 0x80000000;

    var state = riscv.CpuState.init(offset);

    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    const file = try std.fs.cwd().readFileAlloc(arena.allocator(), "../riscv-tests/isa/rv64ui-p-addi", 10320);
    std.debug.print("{d}\n", .{file.len});

    if (!std.mem.eql(u8, file[0..4], &[_]u8{ 0x7f, 'E', 'L', 'F' })) {
        std.debug.print("Invalid ELF!!!\n", .{});
    }

    const elf_header: *std.elf.Elf64_Ehdr = @ptrCast(@alignCast(file.ptr));

    const prog_headers_ptr: [*]std.elf.Elf64_Phdr = @ptrFromInt(@intFromPtr(file.ptr) + elf_header.e_phoff);
    const prog_headers = prog_headers_ptr[0..elf_header.e_phnum];

    for (prog_headers, 0..) |prog_header, i| {
        if (prog_header.p_type != std.elf.PT_LOAD)
            continue;

        std.debug.print("Loaded section at i: {d}\n", .{i});

        const section_ptr: [*]u8 = @ptrFromInt(@intFromPtr(file.ptr) + prog_header.p_offset);
        const addr = prog_header.p_vaddr - offset;

        @memset(state.mem[addr..(addr + prog_header.p_memsz)], 0);
        @memcpy(state.mem[addr..(addr + prog_header.p_filesz)], section_ptr[0..prog_header.p_filesz]);
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
