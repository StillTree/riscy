const std = @import("std");
const cpu_32 = @import("cpu_32.zig");
const a = @import("assembler.zig");

pub fn main() !void {
    var state = cpu_32.CpuState.init();

    const prog = comptime block: {
        const addi = a.assemble("addi x5, x0, 10");
        const addi2 = a.assemble("addi x6, x0, 3");
        const add = a.assemble("add x7, x5, x6");

        break :block addi ++ addi2 ++ add;
    };

    @memcpy(state.mem[0..12], prog[0..12]);

    try state.step();
    try state.step();
    try state.step();

    state.printRegisters();
}
