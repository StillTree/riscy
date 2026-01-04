const std = @import("std");
const cpu_32 = @import("cpu_32.zig");
const a = @import("assembler.zig");

pub fn main() !void {
    var state = cpu_32.CpuState.init();

    const prog = comptime block: {
        const addi = a.assemble("addi x5, x0, 10");
        const addi2 = a.assemble("addi x6, x0, 3");
        const add = a.assemble("add x7, x5, x6");
        const jal = a.assemble("jal x0, 4");
        const add2 = a.assemble("add x7, x7, x6");

        break :block addi ++ addi2 ++ add ++ jal ++ add2;
    };

    @memcpy(state.mem[0..20], prog[0..20]);

    try state.step();
    try state.step();
    try state.step();
    try state.step();
    try state.step();

    state.printRegisters();
}
