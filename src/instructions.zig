const std = @import("std");

pub const Reg = u5;

pub const Opcode = enum(u7) {
    imm = 0b0010011,
    lui = 0b0110111,
    auipc = 0b0010111,
    op = 0b0110011,
};

pub const Instruction = union(enum) {
    typeI: FormatI,
    typeU: FormatU,
    typeR: FormatR,
    unknown: u32,
};

pub const FormatI = struct {
    opcode: Opcode,
    rd: Reg,
    funct3: u3,
    rs1: Reg,
    imm: i12,
};

pub const FormatU = struct {
    opcode: Opcode,
    rd: Reg,
    imm: i20,
};

pub const FormatR = struct {
    opcode: Opcode,
    rd: Reg,
    funct3: u3,
    rs1: Reg,
    rs2: Reg,
    funct7: u7,
};

pub fn decode(raw: u32) Instruction {
    std.debug.print("{b}\n", .{@as(u7, @truncate(raw))});

    const opcode: Opcode = @enumFromInt(@as(u7, @truncate(raw)));

    switch (opcode) {
        .imm => {
            return Instruction{
                .typeI = .{
                    .opcode = opcode,
                    .rd = @truncate(raw >> 7),
                    .funct3 = @truncate(raw >> 12),
                    .rs1 = @truncate(raw >> 15),
                    .imm = @bitCast(@as(u12, @truncate(raw >> 20))),
                },
            };
        },
        .lui, .auipc => {
            return Instruction{
                .typeU = .{
                    .opcode = opcode,
                    .rd = @truncate(raw >> 7),
                    .imm = @bitCast(@as(u20, @truncate(raw >> 12))),
                },
            };
        },
        .op => {
            return Instruction{
                .typeR = .{
                    .opcode = opcode,
                    .rd = @truncate(raw >> 7),
                    .funct3 = @truncate(raw >> 12),
                    .rs1 = @truncate(raw >> 15),
                    .rs2 = @truncate(raw >> 20),
                    .funct7 = @truncate(raw >> 25),
                },
            };
        },
    }
}
