const std = @import("std");
const riscv = @import("riscv_core");

pub fn main() !void {
    var state = riscv.CpuState.init();

    std.debug.print("Nice!\n", .{});

    state.printRegisters();

    // const prog = comptime block: {
    //     const addi = a.assemble("addi x5, x0, 10");
    //     const addi2 = a.assemble("addi x6, x0, 3");
    //     const add = a.assemble("add x7, x5, x6");
    //     const jal = a.assemble("jal x0, 4");
    //     const add2 = a.assemble("add x7, x7, x6");

    //     break :block addi ++ addi2 ++ add ++ jal ++ add2;
    // };

    // @memcpy(state.mem[0..20], prog[0..20]);

    // try state.step();
    // try state.step();
    // try state.step();
    // try state.step();
    // try state.step();
}
