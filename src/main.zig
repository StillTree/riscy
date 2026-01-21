const std = @import("std");
const riscv = @import("riscv_core");

pub fn main() !void {
    var state = riscv.CpuState.init();

    state.printRegisters();

    const testProg = @embedFile("rv64ui-p-addi");

    std.debug.print("Test length: {}\n", .{testProg.len});

    @memcpy(state.mem[0..testProg.len], testProg[0..testProg.len]);

    try state.step();

    // const prog = comptime block: {
    //     const addi = a.assemble("addi x5, x0, 10");
    //     const addi2 = a.assemble("addi x6, x0, 3");
    //     const add = a.assemble("add x7, x5, x6");
    //     const jal = a.assemble("jal x0, 4");
    //     const add2 = a.assemble("add x7, x7, x6");

    //     break :block addi ++ addi2 ++ add ++ jal ++ add2;
    // };
}
