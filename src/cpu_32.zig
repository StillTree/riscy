const std = @import("std");
const isa = @import("instructions.zig");

pub const CpuState = struct {
    reg: [32]i32,
    pc: u32,
    mem: [1024]u8,

    pub fn init() CpuState {
        return .{
            .reg = [_]i32{0} ** 32,
            .pc = 0,
            .mem = [_]u8{0} ** 1024,
        };
    }

    pub fn setReg(self: *CpuState, reg: isa.Reg, value: i32) void {
        if (reg == 0) return;

        self.reg[reg] = value;
    }

    fn execOpcodeImm(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.funct3) {
            // addi
            0b000 => {
                const val = self.reg[inst.rs1] +% inst.imm;
                self.setReg(inst.rd, val);
            },
            // slti
            0b010 => {
                if (self.reg[inst.rs1] < inst.imm) {
                    self.setReg(inst.rd, 1);
                } else {
                    self.setReg(inst.rd, 0);
                }
            },
            // sltiu
            0b011 => {
                if (@as(u32, @bitCast(self.reg[inst.rs1])) < @as(u32, @bitCast(@as(i32, inst.imm)))) {
                    self.setReg(inst.rd, 1);
                } else {
                    self.setReg(inst.rd, 0);
                }
            },
            // xori
            0b100 => {
                const val = self.reg[inst.rs1] ^ inst.imm;
                self.setReg(inst.rd, val);
            },
            // ori
            0b110 => {
                const val = self.reg[inst.rs1] | inst.imm;
                self.setReg(inst.rd, val);
            },
            // andi
            0b111 => {
                const val = self.reg[inst.rs1] & inst.imm;
                self.setReg(inst.rd, val);
            },
            // slli
            0b001 => {
                const shamt: u5 = @truncate(@as(u12, @bitCast(inst.imm)));
                const val = self.reg[inst.rs1] << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u5 = @truncate(@as(u12, @bitCast(inst.imm)));
                const is_arithmetic = ((inst.imm >> 10) & 1) == 1;

                if (is_arithmetic) {
                    // srai
                    const val = self.reg[inst.rs1] >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srli
                    const val = @as(u32, @bitCast(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, @bitCast(val));
                }
            },
        }
    }

    fn execOpcodeLui(self: *CpuState, inst: isa.FormatU) !void {
        const val = inst.imm & ~@as(i32, 0xfff);
        self.setReg(inst.rd, val);
    }

    fn execOpcodeAuipc(self: *CpuState, inst: isa.FormatU) !void {
        const val = @as(u32, @bitCast(inst.imm & ~@as(i32, 0xfff))) +% self.pc;
        self.setReg(inst.rd, @intCast(val));
    }

    fn execOpcodeOp(self: *CpuState, inst: isa.FormatR) !void {
        std.debug.print("{d} {d} {d}", .{inst.rd, inst.rs1, inst.rs2});

        const funct7_flag = ((inst.funct7 >> 5) & 1) == 1;

        switch (inst.funct3) {
            0b000 => {
                if (funct7_flag) {
                    // sub
                    const val = self.reg[inst.rs1] -% self.reg[inst.rs2];
                    self.setReg(inst.rd, val);
                } else {
                    // add
                    const val = self.reg[inst.rs1] +% self.reg[inst.rs2];
                    self.setReg(inst.rd, val);
                }
            },
            // slt
            0b010 => {
                if (self.reg[inst.rs1] < self.reg[inst.rs2]) {
                    self.setReg(inst.rd, 1);
                } else {
                    self.setReg(inst.rd, 0);
                }
            },
            // sltu
            0b011 => {
                if (@as(u32, @bitCast(self.reg[inst.rs1])) < @as(u32, @bitCast(self.reg[inst.rs2]))) {
                    self.setReg(inst.rd, 1);
                } else {
                    self.setReg(inst.rd, 0);
                }
            },
            // xor
            0b100 => {
                const val = self.reg[inst.rs1] ^ self.reg[inst.rs2];
                self.setReg(inst.rd, val);
            },
            // or
            0b110 => {
                const val = self.reg[inst.rs1] | self.reg[inst.rs2];
                self.setReg(inst.rd, val);
            },
            // and
            0b111 => {
                const val = self.reg[inst.rs1] & self.reg[inst.rs2];
                self.setReg(inst.rd, val);
            },
            // sll
            0b001 => {
                const shamt: u5 = @truncate(@as(u32, @bitCast(self.reg[inst.rs2])));
                const val = self.reg[inst.rs1] << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u5 = @truncate(@as(u32, @bitCast(self.reg[inst.rs2])));

                if (funct7_flag) {
                    // sra
                    const val = self.reg[inst.rs1] >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srl
                    const val = @as(u32, @bitCast(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, @bitCast(val));
                }
            },
        }
    }

    fn execTypeI(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.opcode) {
            .imm => try self.execOpcodeImm(inst),
            else => return error.InvalidOpcode,
        }
    }

    fn execTypeU(self: *CpuState, inst: isa.FormatU) !void {
        switch (inst.opcode) {
            .lui => try self.execOpcodeLui(inst),
            .auipc => try self.execOpcodeAuipc(inst),
            else => return error.InvalidOpcode,
        }
    }

    fn execTypeR(self: *CpuState, inst: isa.FormatR) !void {
        switch (inst.opcode) {
            .op => try self.execOpcodeOp(inst),
            else => return error.InvalidOpcode,
        }
    }

    pub fn printRegisters(self: *CpuState) void {
        for (self.reg, 0..) |reg, i| {
            std.debug.print("x{: <2}: {d: <11} 0x{x:0>8}\n", .{ i, reg, @as(u32, @bitCast(reg)) });
        }
    }

    pub fn step(self: *CpuState) !void {
        if (self.pc + 4 > self.mem.len) return error.OutOfMemory;

        const raw = std.mem.readInt(u32, self.mem[self.pc..][0..4], .little);

        const inst = isa.decode(raw);

        switch (inst) {
            .typeI => |i| try self.execTypeI(i),
            .typeU => |i| try self.execTypeU(i),
            .typeR => |i| try self.execTypeR(i),
            .unknown => return error.IllegalInstruction,
        }

        self.pc += 4;
    }
};
