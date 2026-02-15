const std = @import("std");
const riscv = @import("riscv_core");

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    var ram1 = try riscv.Ram.init(arena.allocator(), 4069);
    defer ram1.deinit();
    var ram2 = try riscv.Ram.init(arena.allocator(), 12280);
    defer ram2.deinit();
    var htif = riscv.SimpleHtif.init();

    var state = riscv.CpuState.init(arena.allocator());

    try state.mem_bus.register(ram1.memHandler(0x80000000));
    try state.mem_bus.register(htif.memHandler(0x80001000));
    try state.mem_bus.register(ram2.memHandler(0x80001008));

    const info = try riscv.bin_loader.loadElf(arena.allocator(), &state.mem_bus, "../riscv-tests/isa/rv64ui-p-addi");

    state.pc = info.entry_point;

    for (0..300) |_| {
        try state.step();

        if ((htif.to_host & 1) == 1)
            break;
    }

    const test_exit_code = htif.to_host >> 1;
    if (test_exit_code == 0) {
        std.debug.print("All tests passed!\n", .{});
    } else {
        std.debug.print("Test {} failed!\n", .{test_exit_code});
    }
}
