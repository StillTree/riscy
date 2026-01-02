const std = @import("std");
const cpu_32 = @import("cpu_32.zig");
const a = @import("assembler.zig");

pub fn main() !void {
    var state = cpu_32.CpuState{
        .registers = [_]i32{0} ** 32,
        .prog_counter = 0,
        .mem = [_]u8{0} ** 16,
    };

    state.mem = a.assemble("addi x1, x1, -15") ** 4;

    try cpu_32.run(&state);

    state.printRegisters();
}
