const std = @import("std");
const mem = @import("mem_bus.zig");

pub const BinInfo = struct {
    entry_point: u64,
};

/// Directly loads an ELF file using the provided memory bus. Only supports static files.
pub fn loadElf(alloc: std.mem.Allocator, mem_bus: *mem.Bus, fileName: []const u8) !BinInfo {
    const file = try std.fs.cwd().openFile(fileName, .{ .mode = .read_only });
    defer file.close();
    var reader = file.reader(&.{});

    var elf_header: std.elf.Elf64_Ehdr = undefined;
    try reader.interface.readSliceAll(std.mem.asBytes(&elf_header));

    if (!std.mem.eql(u8, elf_header.e_ident[0..4], std.elf.MAGIC)
        or elf_header.e_ident[std.elf.EI_CLASS] != std.elf.ELFCLASS64
        or elf_header.e_machine != .RISCV
        or elf_header.e_ident[std.elf.EI_DATA] != std.elf.ELFDATA2LSB
        or elf_header.e_type != .EXEC
        or elf_header.e_phnum <= 0
        or elf_header.e_phentsize != @sizeOf(std.elf.Elf64_Phdr)) {
        return error.InvalidElf;
    }

    for (0..elf_header.e_phnum) |i| {
        try reader.seekTo(elf_header.e_phoff + i * elf_header.e_phentsize);
        var prog_header: std.elf.Elf64_Phdr = undefined;
        try reader.interface.readSliceAll(std.mem.asBytes(&prog_header));

        if (prog_header.p_type != std.elf.PT_LOAD)
            continue;

        if (prog_header.p_filesz > prog_header.p_memsz)
            return error.InvalidElfSegment;

        try reader.seekTo(prog_header.p_offset);
        const section_data = try reader.interface.readAlloc(alloc, prog_header.p_filesz);
        defer alloc.free(section_data);

        const load_begin = prog_header.p_vaddr;
        const load_end = load_begin + prog_header.p_filesz;
        const zero_begin = load_end;
        const zero_end = load_end + prog_header.p_memsz - prog_header.p_filesz;

        for (load_begin..load_end) |addr| {
            try mem_bus.store(u8, addr, section_data[addr - load_begin]);
        }

        for (zero_begin..zero_end) |addr| {
            try mem_bus.store(u8, addr, 0);
        }
    }

    return .{
        .entry_point = elf_header.e_entry,
    };
}
