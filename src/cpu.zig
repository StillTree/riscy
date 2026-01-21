const std = @import("std");
const isa = @import("instructions.zig");
const csr = @import("csr.zig");

pub const Priv = enum(u2) {
    user = 0b00,
    supervisor = 0b01,
    machine = 0b11,
};

pub const CpuState = struct {
    reg: [32]i64,
    pc: u64,
    mem: [16384]u8,
    cur_priv: Priv,
    csr_state: csr.State,

    pub fn init() CpuState {
        return .{
            .reg = [_]i64{0} ** 32,
            .pc = 0,
            .mem = [_]u8{0} ** 16384,
            .cur_priv = .machine,
            .csr_state = csr.State.init(),
        };
    }

    pub fn setReg(self: *CpuState, reg: isa.Reg, value: i64) void {
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
                if (@as(u64, @bitCast(self.reg[inst.rs1])) < @as(u64, @bitCast(@as(i64, inst.imm)))) {
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
                const shamt: u6 = @truncate(@as(u12, @bitCast(inst.imm)));
                const val = self.reg[inst.rs1] << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u6 = @truncate(@as(u12, @bitCast(inst.imm)));
                const is_arithmetic = ((inst.imm >> 10) & 1) == 1;

                if (is_arithmetic) {
                    // srai
                    const val = self.reg[inst.rs1] >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srli
                    const val = @as(u64, @bitCast(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, @bitCast(val));
                }
            },
        }
    }

    fn execOpcodeImm32(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.funct3) {
            // addiw
            0b000 => {
                const val = @as(i32, @truncate(self.reg[inst.rs1])) +% inst.imm;
                self.setReg(inst.rd, val);
            },
            // slliw
            0b001 => {
                const shamt: u5 = @truncate(@as(u12, @bitCast(inst.imm)));
                const val = @as(i32, @truncate(self.reg[inst.rs1])) << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u5 = @truncate(@as(u12, @bitCast(inst.imm)));
                const is_arithmetic = ((inst.imm >> 10) & 1) == 1;

                if (is_arithmetic) {
                    // sraiw
                    const val = @as(i32, @truncate(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srliw
                    const val: i32 = @bitCast(@as(u32, @bitCast(@as(i32, @truncate(self.reg[inst.rs1])))) >> shamt);
                    self.setReg(inst.rd, val);
                }
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeLui(self: *CpuState, inst: isa.FormatU) !void {
        const val = @as(i64, inst.imm) << 12;
        self.setReg(inst.rd, val);
    }

    fn execOpcodeAuipc(self: *CpuState, inst: isa.FormatU) !void {
        const val = (@as(i64, inst.imm) << 12) +% @as(i64, @bitCast(self.pc));
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
                if (@as(u64, @bitCast(self.reg[inst.rs1])) < @as(u64, @bitCast(self.reg[inst.rs2]))) {
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
                const shamt: u6 = @truncate(@as(u64, @bitCast(self.reg[inst.rs2])));
                const val = self.reg[inst.rs1] << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u6 = @truncate(@as(u64, @bitCast(self.reg[inst.rs2])));

                if (funct7_flag) {
                    // sra
                    const val = self.reg[inst.rs1] >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srl
                    const val = @as(u64, @bitCast(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, @bitCast(val));
                }
            },
        }
    }

    fn execOpcodeOp32(self: *CpuState, inst: isa.FormatR) !void {
        const funct7_flag = ((inst.funct7 >> 5) & 1) == 1;

        switch (inst.funct3) {
            0b000 => {
                if (funct7_flag) {
                    // subw
                    const val = @as(i32, @truncate(self.reg[inst.rs1])) -% @as(i32, @truncate(self.reg[inst.rs2]));
                    self.setReg(inst.rd, val);
                } else {
                    // addw
                    const val = @as(i32, @truncate(self.reg[inst.rs1])) +% @as(i32, @truncate(self.reg[inst.rs2]));
                    self.setReg(inst.rd, val);
                }
            },
            // sll
            0b001 => {
                const shamt: u5 = @truncate(@as(u64, @bitCast(self.reg[inst.rs2])));
                const val = @as(i32, @truncate(self.reg[inst.rs1])) << shamt;
                self.setReg(inst.rd, val);
            },
            0b101 => {
                const shamt: u5 = @truncate(@as(u64, @bitCast(self.reg[inst.rs2])));

                if (funct7_flag) {
                    // sra
                    const val = @as(i32, @truncate(self.reg[inst.rs1])) >> shamt;
                    self.setReg(inst.rd, val);
                } else {
                    // srl
                    const val: i32 = @bitCast(@as(u32, @bitCast(@as(i32, @truncate(self.reg[inst.rs1])))) >> shamt);
                    self.setReg(inst.rd, val);
                }
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeJal(self: *CpuState, inst: isa.FormatJ) !void {
        const imm: i64 = @intCast(@as(i21, @bitCast((inst.imm_1_10 << 1) |
            (@as(i21, inst.imm_11) << 11) |
            (@as(i21, inst.imm_12_19) << 12) |
            (@as(i21, inst.imm_20) << 20))));
        const target: u64 = self.pc +% @as(u64, @bitCast(imm));
        self.setReg(inst.rd, @bitCast(self.pc + 4));
        // This is done to compensate for the main loop that always increments the program counter after executing an instruction
        self.pc = target -% 4;
    }

    fn execOpcodeJalr(self: *CpuState, inst: isa.FormatI) !void {
        const target: u64 = @as(u64, @bitCast((self.reg[inst.rs1] +% inst.imm))) & ~@as(u64, 1);
        self.setReg(inst.rd, @bitCast(self.pc + 4));
        // This is done to compensate for the main loop that always increments the program counter after executing an instruction
        self.pc = target -% 4;
    }

    fn execOpcodeBranch(self: *CpuState, inst: isa.FormatB) !void {
        const imm: i64 = @intCast(@as(i13, @bitCast((inst.imm_1_4 << 1) |
            (@as(i13, inst.imm_5_10) << 5) |
            (@as(i13, inst.imm_11) << 11) |
            (@as(i13, inst.imm_12) << 12))));
        const target: u64 = self.pc +% @as(u64, @bitCast(imm));

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
                if (@as(u64, @bitCast(self.reg[inst.rs1])) < @as(u64, @bitCast(self.reg[inst.rs2]))) {
                    self.pc = target -% 4;
                }
            },
            // bgeu
            0b111 => {
                if (@as(u64, @bitCast(self.reg[inst.rs1])) >= @as(u64, @bitCast(self.reg[inst.rs2]))) {
                    self.pc = target -% 4;
                }
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeLoad(self: *CpuState, inst: isa.FormatI) !void {
        const addr: u64 = @bitCast(self.reg[inst.rs1] +% inst.imm);

        switch (inst.funct3) {
            // lb
            0b000 => {
                const val: i8 = @bitCast(self.mem[addr]);
                self.setReg(inst.rd, val);
            },
            // lbu
            0b100 => {
                const val: u64 = self.mem[addr];
                self.setReg(inst.rd, @bitCast(val));
            },
            // lh
            0b001 => {
                const val = std.mem.readInt(i16, self.mem[addr..][0..2], .little);
                self.setReg(inst.rd, val);
            },
            // lhu
            0b101 => {
                const val: u64 = std.mem.readInt(u16, self.mem[addr..][0..2], .little);
                self.setReg(inst.rd, @bitCast(val));
            },
            // lw
            0b010 => {
                const val = std.mem.readInt(i32, self.mem[addr..][0..4], .little);
                self.setReg(inst.rd, val);
            },
            // lwu
            0b110 => {
                const val: u64 = std.mem.readInt(u32, self.mem[addr..][0..4], .little);
                self.setReg(inst.rd, @bitCast(val));
            },
            // ld
            0b011 => {
                const val = std.mem.readInt(i64, self.mem[addr..][0..8], .little);
                self.setReg(inst.rd, val);
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeStore(self: *CpuState, inst: isa.FormatS) !void {
        const imm: i12 = @bitCast(inst.imm_0_4 | (@as(u12, inst.imm_5_11) << 5));
        const addr: u64 = @bitCast(self.reg[inst.rs1] +% imm);

        switch (inst.funct3) {
            // sb
            0b000 => {
                const val: i8 = @truncate(self.reg[inst.rs2]);
                self.mem[addr] = @bitCast(val);
            },
            // sh
            0b001 => {
                const val: i16 = @truncate(self.reg[inst.rs2]);
                std.mem.writeInt(i16, self.mem[addr..][0..2], val, .little);
            },
            // sw
            0b010 => {
                const val: i32 = @truncate(self.reg[inst.rs2]);
                std.mem.writeInt(i32, self.mem[addr..][0..4], val, .little);
            },
            // sd
            0b011 => {
                const val: i64 = self.reg[inst.rs2];
                std.mem.writeInt(i64, self.mem[addr..][0..8], val, .little);
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execOpcodeSystem(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.funct3) {
            0b000 => {
                const funct12: u12 = @bitCast(inst.imm);

                switch (funct12) {
                    // ecall
                    0b0000000000 => {
                        try self.trap(csr.Cause.ecall_from_machine);
                    },
                    // ebreak
                    0b1000000000 => return error.Halt,
                    // mret
                    0b1100000010 => {
                        // TOOD: Finish this
                        const mpie = (try self.csr_state.read(csr.Addr.mstatus) >> csr.Status.MPIE_SHIFT) & 1;
                        const mstatus_masked = try self.csr_state.read(csr.Addr.mstatus) & ~@as(u64, 1 << csr.Status.MIE_SHIFT);

                        const new_mstatus = mstatus_masked | (mpie << csr.Status.MIE_SHIFT);
                        try self.csr_state.write(csr.Addr.mstatus, new_mstatus);
                        self.pc = try self.csr_state.read(csr.Addr.mepc);
                    },
                    else => return error.InvalidFunct12,
                }
            },
            // csrrw
            0b001 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                if (inst.rd != 0) {
                    const csrVal: u64 = try self.csr_state.read(addr);
                    self.setReg(inst.rd, @bitCast(csrVal));
                }
                try self.csr_state.write(addr, @bitCast(self.reg[inst.rs1]));
            },
            // csrrs
            0b010 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                const csrVal: u64 = try self.csr_state.read(addr);
                self.setReg(inst.rd, @bitCast(csrVal));
                if (inst.rs1 != 0) {
                    try self.csr_state.write(addr, @bitCast(csrVal | @as(u64, @bitCast(self.reg[inst.rs1]))));
                }
            },
            // csrrc
            0b011 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                const csrVal: u64 = try self.csr_state.read(addr);
                self.setReg(inst.rd, @bitCast(csrVal));
                if (inst.rs1 != 0) {
                    try self.csr_state.write(addr, @bitCast(csrVal & ~@as(u64, @bitCast(self.reg[inst.rs1]))));
                }
            },
            // csrrwi
            0b101 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                if (inst.rd != 0) {
                    const csrVal: u64 = try self.csr_state.read(addr);
                    self.setReg(inst.rd, @bitCast(csrVal));
                }
                try self.csr_state.write(addr, inst.rs1);
            },
            // csrrsi
            0b110 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                const csrVal: u64 = try self.csr_state.read(addr);
                self.setReg(inst.rd, @bitCast(csrVal));
                if (inst.rs1 != 0) {
                    try self.csr_state.write(addr, csrVal | inst.rs1);
                }
            },
            // csrrci
            0b111 => {
                const addr: csr.Addr = @enumFromInt(@as(u12, @bitCast(inst.imm)));
                const csrVal: u64 = try self.csr_state.read(addr);
                self.setReg(inst.rd, @bitCast(csrVal));
                if (inst.rs1 != 0) {
                    try self.csr_state.write(addr, csrVal & ~@as(u64, inst.rs1));
                }
            },
            else => return error.InvalidFunct3,
        }
    }

    fn execTypeI(self: *CpuState, inst: isa.FormatI) !void {
        switch (inst.opcode) {
            .imm => try self.execOpcodeImm(inst),
            .imm32 => try self.execOpcodeImm32(inst),
            .jalr => try self.execOpcodeJalr(inst),
            .load => try self.execOpcodeLoad(inst),
            // TODO: Make only FENCE FENCE.TSO and FENCE.I instruction nop
            .misc_mem => return,
            .system => try self.execOpcodeSystem(inst),
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
            .op32 => try self.execOpcodeOp32(inst),
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
            std.debug.print("x{: <2}: {d: <21} 0x{x:0>16}\n", .{ i, reg, @as(u64, @bitCast(reg)) });
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

    pub fn trap(self: *CpuState, cause: csr.Cause) !void {
        // This is obviously very much not complete
        // TODO: Finish this
        const mie = (try self.csr_state.read(csr.Addr.mstatus) >> csr.Status.MIE_SHIFT) & 1;
        const mstatus_masked = try self.csr_state.read(csr.Addr.mstatus) & ~@as(u64, 1 << csr.Status.MPIE_SHIFT);

        const new_mstatus = mstatus_masked | (mie << csr.Status.MPIE_SHIFT);
        try self.csr_state.write(csr.Addr.mstatus, new_mstatus);
        try self.csr_state.write(csr.Addr.mcause, @intFromEnum(cause));
        try self.csr_state.write(csr.Addr.mepc, self.pc);

        const mtvec = try self.csr_state.read(csr.Addr.mtvec);
        const mode: csr.MtvecMode = @enumFromInt(mtvec & 3);
        if (mode == .vectored)
            return error.MtvecModeUnsupported;

        self.pc = mtvec & ~@as(u64, 3);
    }
};
