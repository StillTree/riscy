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

    fn execOpcodeJal(self: *CpuState, inst: isa.FormatJ) !void {
        const imm: i32 = @intCast(@as(i21, @bitCast((inst.imm_1_10 << 1) |
            (@as(i21, inst.imm_11) << 11) |
            (@as(i21, inst.imm_12_19) << 12) |
            (@as(i21, inst.imm_20) << 20))));
        const target: u32 = self.pc +% @as(u32, @bitCast(imm));
        self.setReg(inst.rd, @bitCast(self.pc + 4));
        // This is done to compensate for the main loop that always increments the program counter after executing an instruction
        self.pc = target -% 4;
    }

    fn execOpcodeJalr(self: *CpuState, inst: isa.FormatI) !void {
        const target: u32 = @as(u32, @bitCast((self.reg[inst.rs1] +% inst.imm))) & ~@as(u32, 1);
        self.setReg(inst.rd, @bitCast(self.pc + 4));
        // This is done to compensate for the main loop that always increments the program counter after executing an instruction
        self.pc = target -% 4;
    }

    fn execOpcodeBranch(self: *CpuState, inst: isa.FormatB) !void {
        const imm: i32 = @intCast(@as(i13, @bitCast((inst.imm_1_4 << 1) |
            (@as(i13, inst.imm_5_10) << 5) |
            (@as(i13, inst.imm_11) << 11) |
            (@as(i13, inst.imm_12) << 12))));
        const target: u32 = self.pc +% @as(u32, @bitCast(imm));

        switch (inst.funct3) {
            // beq
            0b000 => {
                if (self.reg[inst.rs1] == self.reg[inst.rs2]) {
                    self.pc = target -% 4;
                }
            },
            // bne
            0b001 => {
                if (self.reg[inst.rs1] != self.reg[inst.rs2]) {
                    self.pc = target -% 4;
                }
            },
            // blt
            0b100 => {
                if (self.reg[inst.rs1] < self.reg[inst.rs2]) {
                    self.pc = target -% 4;
                }
            },
            // bge
            0b101 => {
                if (self.reg[inst.rs1] >= self.reg[inst.rs2]) {
                    self.pc = target -% 4;
                }
            },
            // bltu
            0b110 => {
                if (@as(u32, @bitCast(self.reg[inst.rs1])) < @as(u32, @bitCast(self.reg[inst.rs2]))) {
                    self.pc = target -% 4;
                }
            },
            // bgeu
            0b111 => {
                if (@as(u32, @bitCast(self.reg[inst.rs1])) >= @as(u32, @bitCast(self.reg[inst.rs2]))) {
                    self.pc = target -% 4;
                }
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeLoad(self: *CpuState, inst: isa.FormatI) !void {
        const addr: u32 = @bitCast(self.reg[inst.rs1] +% inst.imm);

        switch (inst.funct3) {
            // lb
            0b000 => {
                const val: i8 = @bitCast(self.mem[addr]);
                self.setReg(inst.rd, val);
            },
            // lbu
            0b100 => {
                const val: u8 = self.mem[addr];
                self.setReg(inst.rd, @as(i32, val));
            },
            // lh
            0b001 => {
                const val = std.mem.readInt(i16, self.mem[addr..][0..2], .little);
                self.setReg(inst.rd, val);
            },
            // lhu
            0b101 => {
                const val = std.mem.readInt(u16, self.mem[addr..][0..2], .little);
                self.setReg(inst.rd, @as(i32, val));
            },
            // lw
            0b010 => {
                const val = std.mem.readInt(i32, self.mem[addr..][0..4], .little);
                self.setReg(inst.rd, val);
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeStore(self: *CpuState, inst: isa.FormatS) !void {
        const imm: i12 = @bitCast(inst.imm_0_4 | (@as(u12, inst.imm_5_11) << 5));
        const addr: u32 = @bitCast(self.reg[inst.rs1] +% imm);

        switch (inst.funct3) {
            // sb
            0b000 => {
                const val: u8 = @truncate(@as(u32, @bitCast(self.reg[inst.rs2])));
                self.mem[addr] = val;
            },
            // sh
            0b001 => {
                const val: u16 = @truncate(@as(u32, @bitCast(self.reg[inst.rs2])));
                std.mem.writeInt(u16, self.mem[addr..][0..2], val, .little);
            },
            // sw
            0b010 => {
                const val: u32 = @bitCast(self.reg[inst.rs2]);
                std.mem.writeInt(u32, self.mem[addr..][0..4], val, .little);
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execTypeI(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.opcode) {
            .imm => try self.execOpcodeImm(inst),
            .jalr => try self.execOpcodeJalr(inst),
            .load => try self.execOpcodeLoad(inst),
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

    fn execTypeJ(self: *CpuState, inst: isa.FormatJ) !void {
        switch (inst.opcode) {
            .jal => try self.execOpcodeJal(inst),
            else => return error.InvalidOpcode,
        }
    }

    fn execTypeB(self: *CpuState, inst: isa.FormatB) !void {
        switch (inst.opcode) {
            .branch => try self.execOpcodeBranch(inst),
            else => return error.InvalidOpcode,
        }
    }

    fn execTypeS(self: *CpuState, inst: isa.FormatS) !void {
        switch (inst.opcode) {
            .store => try self.execOpcodeStore(inst),
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
            .typeJ => |i| try self.execTypeJ(i),
            .typeB => |i| try self.execTypeB(i),
            .typeS => |i| try self.execTypeS(i),
            .unknown => return error.IllegalInstruction,
        }

        self.pc += 4;
    }
};
