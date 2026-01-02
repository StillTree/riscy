const std = @import("std");
const instructions = @import("instructions.zig");

pub const CpuState = struct {
    registers: [32]i32,
    prog_counter: u32,
    mem: [16]u8,

    pub fn printRegisters(self: *CpuState) void {
        for (self.registers, 0..) |reg, i| {
            std.debug.print("x{d}: {d}\n", .{ i, reg });
        }
    }
};

const RiscError = error{InstructionUnaligned};

fn execImm(funct3: instructions.OpImm, instruction: u32, state: *CpuState) RiscError!void {
    const rd: u5 = @truncate(instruction >> 7);
    const rs1: u5 = @truncate(instruction >> 15);
    const imm: i32 = @as(i12, @bitCast(@as(u12, @truncate(instruction >> 20))));

    switch (funct3) {
        .addi => {
            state.registers[rd] = state.registers[rs1] + imm;
        },
    }
}

pub fn run(state: *CpuState) RiscError!void {
    while (true) {
        if (state.prog_counter >= state.mem.len) break;

        if (state.prog_counter % 4 != 0) return RiscError.InstructionUnaligned;

        const instruction: u32 =
            @as(u32, state.mem[state.prog_counter]) |
            @as(u32, state.mem[state.prog_counter + 1]) << 8 |
            @as(u32, state.mem[state.prog_counter + 2]) << 16 |
            @as(u32, state.mem[state.prog_counter + 3]) << 24;

        const opcode: instructions.Opcode = @enumFromInt(instruction & 0x7f);

        switch (opcode) {
            .imm => {
                const funct3: instructions.OpImm = @enumFromInt((instruction >> 12) & 0x7);

                try execImm(funct3, instruction, state);
            },
        }

        state.prog_counter += 4;
    }
}
