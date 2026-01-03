const std = @import("std");
const isa = @import("instructions.zig");

const OpDef = struct {
    opcode: isa.Opcode,
    funct3: ?u3,
    funct7: ?u7,
};

const opDefs = std.StaticStringMap(OpDef).initComptime(.{
    .{ "addi", OpDef{ .opcode = .imm, .funct3 = 0b000, .funct7 = null } },
    .{ "slti", OpDef{ .opcode = .imm, .funct3 = 0b010, .funct7 = null } },
    .{ "sltiu", OpDef{ .opcode = .imm, .funct3 = 0b011, .funct7 = null } },
    .{ "xori", OpDef{ .opcode = .imm, .funct3 = 0b100, .funct7 = null } },
    .{ "ori", OpDef{ .opcode = .imm, .funct3 = 0b110, .funct7 = null } },
    .{ "andi", OpDef{ .opcode = .imm, .funct3 = 0b111, .funct7 = null } },
    .{ "slli", OpDef{ .opcode = .imm, .funct3 = 0b001, .funct7 = null } },
    .{ "srli", OpDef{ .opcode = .imm, .funct3 = 0b101, .funct7 = 0 } },
    .{ "srai", OpDef{ .opcode = .imm, .funct3 = 0b101, .funct7 = 0b0100000 } },
    .{ "lui", OpDef{ .opcode = .lui, .funct3 = null, .funct7 = null } },
    .{ "auipc", OpDef{ .opcode = .auipc, .funct3 = null, .funct7 = null } },
    .{ "add", OpDef{ .opcode = .op, .funct3 = 0b000, .funct7 = 0 } },
    .{ "sub", OpDef{ .opcode = .op, .funct3 = 0b000, .funct7 = 0b0100000 } },
    .{ "slt", OpDef{ .opcode = .op, .funct3 = 0b010, .funct7 = null } },
    .{ "sltu", OpDef{ .opcode = .op, .funct3 = 0b011, .funct7 = null } },
    .{ "xor", OpDef{ .opcode = .op, .funct3 = 0b100, .funct7 = null } },
    .{ "or", OpDef{ .opcode = .op, .funct3 = 0b110, .funct7 = null } },
    .{ "and", OpDef{ .opcode = .op, .funct3 = 0b111, .funct7 = null } },
    .{ "sll", OpDef{ .opcode = .op, .funct3 = 0b001, .funct7 = null } },
    .{ "srl", OpDef{ .opcode = .op, .funct3 = 0b001, .funct7 = 0 } },
    .{ "sra", OpDef{ .opcode = .op, .funct3 = 0b001, .funct7 = 0b0100000 } },
});

fn nextToken(inst: []const u8, i: *usize) ?[]const u8 {
    while (i.* < inst.len and (inst[i.*] == ' ' or inst[i.*] == '\t' or inst[i.*] == ',')) : (i.* += 1) {}

    if (i.* >= inst.len) return null;

    const tokenStart = i.*;

    while (i.* < inst.len and (inst[i.*] != ' ' and inst[i.*] != '\t' and inst[i.*] != ',')) : (i.* += 1) {}

    return inst[tokenStart..i.*];
}

fn parseTypeI(inst: []const u8, instNumbers: OpDef, i: *usize) [4]u8 {
    const rdToken = nextToken(inst, i) orelse @compileError("Missing rd");
    const rs1Token = nextToken(inst, i) orelse @compileError("Missing rs1");
    const immToken = nextToken(inst, i) orelse @compileError("Missing imm");

    if (rdToken[0] != 'x') @compileError("Invalid rd format");
    if (rs1Token[0] != 'x') @compileError("Invalid rs1 format");

    const rd = std.fmt.parseInt(u5, rdToken[1..], 10) catch @compileError("Invalid rd format");
    const rs1 = std.fmt.parseInt(u5, rs1Token[1..], 10) catch @compileError("Invalid rs1 format");
    const imm = std.fmt.parseInt(i12, immToken, 10) catch @compileError("Invalid imm format");

    const funct3 = instNumbers.funct3 orelse @compileError("Empty funct3");

    const instruction: u32 =
        @intFromEnum(instNumbers.opcode) |
        (@as(u32, rd) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1) << 15) |
        (@as(u32, @bitCast(@as(i32, imm))) << 20);

    return @bitCast(instruction);
}

fn parseTypeU(inst: []const u8, instNumbers: OpDef, i: *usize) [4]u8 {
    const rdToken = nextToken(inst, i) orelse @compileError("Missing rd");
    const immToken = nextToken(inst, i) orelse @compileError("Missing imm");

    if (rdToken[0] != 'x') @compileError("Invalid rd format");

    const rd = std.fmt.parseInt(u5, rdToken[1..], 10) catch @compileError("Invalid rd format");
    const imm = std.fmt.parseInt(i20, immToken, 10) catch @compileError("Invalid imm format");

    const instruction: u32 =
        @intFromEnum(instNumbers.opcode) |
        (@as(u32, rd) << 7) |
        (@as(u32, @bitCast(@as(i32, imm))) << 12);

    return @bitCast(instruction);
}

fn parseTypeR(inst: []const u8, instNumbers: OpDef, i: *usize) [4]u8 {
    const rdToken = nextToken(inst, i) orelse @compileError("Missing rd");
    const rs1Token = nextToken(inst, i) orelse @compileError("Missing rs1");
    const rs2Token = nextToken(inst, i) orelse @compileError("Missing rs1");

    if (rdToken[0] != 'x') @compileError("Invalid rd format");
    if (rs1Token[0] != 'x') @compileError("Invalid rs1 format");
    if (rs2Token[0] != 'x') @compileError("Invalid rs2 format");

    const rd = std.fmt.parseInt(u5, rdToken[1..], 10) catch @compileError("Invalid rd format");
    const rs1 = std.fmt.parseInt(u5, rs1Token[1..], 10) catch @compileError("Invalid rs1 format");
    const rs2 = std.fmt.parseInt(u5, rs2Token[1..], 10) catch @compileError("Invalid rs2 format");

    const funct3 = instNumbers.funct3 orelse @compileError("Empty funct3");
    const funct7 = instNumbers.funct7 orelse 0;

    const instruction: u32 =
        @intFromEnum(instNumbers.opcode) |
        (@as(u32, rd) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1) << 15) |
        (@as(u32, rs2) << 20) |
        (@as(u32, funct7) << 25);

    return @bitCast(instruction);
}

pub fn assemble(comptime inst: []const u8) [4]u8 {
    var i: usize = 0;

    const opToken = nextToken(inst, &i) orelse @compileError("Empty string provided");

    const opDef: OpDef = opDefs.get(opToken) orelse @compileError("Invalid/unimplemented opeartion");

    return switch (opDef.opcode) {
        .imm => parseTypeI(inst, opDef, &i),
        .lui, .auipc => parseTypeU(inst, opDef, &i),
        .op => parseTypeR(inst, opDef, &i),
    };
}
