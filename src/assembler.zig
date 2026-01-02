const std = @import("std");

fn nextToken(comptime inst: []const u8, comptime i: *usize) ?[]const u8 {
    while (i.* < inst.len and (inst[i.*] == ' ' or inst[i.*] == '\t' or inst[i.*] == ',')) : (i.* += 1) {}

    if (i.* >= inst.len) return null;

    const tokenStart = i.*;

    while (i.* < inst.len and (inst[i.*] != ' ' and inst[i.*] != '\t' and inst[i.*] != ',')) : (i.* += 1) {}

    return inst[tokenStart..i.*];
}

fn assembleRegImm(comptime opcode: u7, comptime rd: u5, comptime funct3: u3, comptime rs1: u5, comptime imm: i12) [4]u8 {
    const inst: u32 =
        opcode |
        (@as(u32, rd) << 7) | 
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1) << 15) |
        (@as(u32, @bitCast(@as(i32, imm))) << 20);

    return @bitCast(inst);
}

pub fn assemble(comptime inst: []const u8) [4]u8 {
    comptime var i: usize = 0;

    const instToken = comptime nextToken(inst, &i) orelse @compileError("Empty string provided");

    if (!(comptime std.mem.eql(u8, instToken, "addi"))) @compileError("Unknown instruction");

    const rd = comptime nextToken(inst, &i) orelse @compileError("Missing rd");
    const rs1 = comptime nextToken(inst, &i) orelse @compileError("Missing rs1");
    const imm = comptime nextToken(inst, &i) orelse @compileError("Missing imm");

    if (rd[0] != 'x') @compileError("Invalid rd format");
    if (rs1[0] != 'x') @compileError("Invalid rd format");

    const rdNum = comptime std.fmt.parseInt(u5, rd[1..], 10) catch @compileError("Invalid rd format");
    const rs1Num = comptime std.fmt.parseInt(u5, rs1[1..], 10) catch @compileError("Invalid rs1 format");
    const immVal = comptime std.fmt.parseInt(i12, imm, 10) catch @compileError("Invalid imm format");

    return assembleRegImm(0b0010011, rdNum, 0b000, rs1Num, immVal);
}
