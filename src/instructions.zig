const std = @import("std");

pub const Reg = u5;

pub const Opcode = enum(u7) {
    imm = 0b0010011,
    imm32 = 0b0011011,
    lui = 0b0110111,
    auipc = 0b0010111,
    op = 0b0110011,
    op32 = 0b0111011,
    jal = 0b1101111,
    jalr = 0b1100111,
    branch = 0b1100011,
    load = 0b0000011,
    store = 0b0100011,
    misc_mem = 0b0001111,
    system = 0b1110011,
    _,
};

pub const Instruction = union(enum) {
    typeI: FormatI,
    typeU: FormatU,
    typeR: FormatR,
    typeJ: FormatJ,
    typeB: FormatB,
    typeS: FormatS,
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

pub const FormatJ = struct {
    opcode: Opcode,
    rd: Reg,
    imm_12_19: u8,
    imm_11: u1,
    imm_1_10: u10,
    imm_20: u1,
};

pub const FormatB = struct {
    opcode: Opcode,
    imm_11: u1,
    imm_1_4: u4,
    funct3: u3,
    rs1: Reg,
    rs2: Reg,
    imm_5_10: u6,
    imm_12: u1,
};

pub const FormatS = struct {
    opcode: Opcode,
    imm_0_4: u5,
    funct3: u3,
    rs1: Reg,
    rs2: Reg,
    imm_5_11: u7,
};

pub fn decode(raw: u32) Instruction {
    const opcode: Opcode = @enumFromInt(@as(u7, @truncate(raw)));

    switch (opcode) {
        .imm, .imm32, .jalr, .load, .misc_mem, .system => {
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
        .op, .op32 => {
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
        .jal => {
            return Instruction{
                .typeJ = .{
                    .opcode = opcode,
                    .rd = @truncate(raw >> 7),
                    .imm_12_19 = @truncate(raw >> 12),
                    .imm_11 = @truncate(raw >> 20),
                    .imm_1_10 = @truncate(raw >> 21),
                    .imm_20 = @truncate(raw >> 31),
                },
            };
        },
        .branch => {
            return Instruction{
                .typeB = .{
                    .opcode = opcode,
                    .imm_11 = @truncate(raw >> 7),
                    .imm_1_4 = @truncate(raw >> 8),
                    .funct3 = @truncate(raw >> 12),
                    .rs1 = @truncate(raw >> 15),
                    .rs2 = @truncate(raw >> 20),
                    .imm_5_10 = @truncate(raw >> 25),
                    .imm_12 = @truncate(raw >> 31),
                },
            };
        },
        .store => {
            return Instruction{
                .typeS = .{
                    .opcode = opcode,
                    .imm_0_4 = @truncate(raw >> 7),
                    .funct3 = @truncate(raw >> 12),
                    .rs1 = @truncate(raw >> 15),
                    .rs2 = @truncate(raw >> 20),
                    .imm_5_11 = @truncate(raw >> 25),
                },
            };
        },
        _ => {
            return Instruction{
                .unknown = raw,
            };
        },
    }
}
