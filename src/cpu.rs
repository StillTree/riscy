use crate::{
    csr::CsrState,
    dev::Bus,
    instructions::{EncodingB, EncodingI, EncodingIShifts, EncodingJ, EncodingR, EncodingS, EncodingU},
};

pub enum Exception {
    LoadAccessFault,
    StoreAccessFault,
}

pub enum PrivMode {
    Machine = 0b11,
    Supervisor = 0b01,
    User = 0b00,
}

struct Cpu {
    mem: Bus,
    csr: CsrState,
    reg: [i64; 32],
    pc: u64,
}

impl Cpu {
    pub fn new(mem: Bus, csr: CsrState) -> Self {
        Cpu {
            reg: [0; 32],
            mem,
            csr,
            pc: 0,
        }
    }

    fn set_reg(self: &mut Cpu, reg: u8, val: i64) {
        if reg == 0 {
            return;
        }

        self.reg[reg as usize] = val;
    }

    fn get_reg(self: &Cpu, reg: u8) -> i64 {
        self.reg[reg as usize]
    }

    pub fn step(self: &mut Cpu) {}
}

impl Cpu {
    fn addi(&mut self, inst: EncodingI) {
        let val = self.get_reg(inst.rs1).wrapping_add(inst.imm);
        self.set_reg(inst.rd, val);
    }

    fn slti(&mut self, inst: EncodingI) {
        self.set_reg(inst.rd, (self.get_reg(inst.rs1) < inst.imm) as i64);
    }

    fn sltiu(&mut self, inst: EncodingI) {
        self.set_reg(inst.rd, ((self.get_reg(inst.rs1) as u64) < (inst.imm as u64)) as i64);
    }

    fn xori(&mut self, inst: EncodingI) {
        let val = self.get_reg(inst.rs1) ^ inst.imm;
        self.set_reg(inst.rd, val);
    }

    fn ori(&mut self, inst: EncodingI) {
        let val = self.get_reg(inst.rs1) | inst.imm;
        self.set_reg(inst.rd, val);
    }

    fn andi(&mut self, inst: EncodingI) {
        let val = self.get_reg(inst.rs1) & inst.imm;
        self.set_reg(inst.rd, val);
    }

    fn slli(&mut self, inst: EncodingIShifts) {
        let val = self.get_reg(inst.rs1).wrapping_shl(inst.shamt as u32);
        self.set_reg(inst.rd, val);
    }

    fn srli(&mut self, inst: EncodingIShifts) {
        let val = (self.get_reg(inst.rs1) as u64).wrapping_shr(inst.shamt as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn srai(&mut self, inst: EncodingIShifts) {
        let val = self.get_reg(inst.rs1).wrapping_shr(inst.shamt as u32);
        self.set_reg(inst.rd, val);
    }

    fn addiw(&mut self, inst: EncodingI) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_add(inst.imm as i32);
        self.set_reg(inst.rd, val as i64);
    }

    fn slliw(&mut self, inst: EncodingIShifts) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_shl(inst.shamt as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn srliw(&mut self, inst: EncodingIShifts) {
        let val = (self.get_reg(inst.rs1) as u32).wrapping_shr(inst.shamt as u32) as i32;
        self.set_reg(inst.rd, val as i64);
    }

    fn sraiw(&mut self, inst: EncodingIShifts) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_shr(inst.shamt as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn lui(&mut self, inst: EncodingU) {
        self.set_reg(inst.rd, inst.imm);
    }

    fn auipc(&mut self, inst: EncodingU) {
        let val = inst.imm.wrapping_add(self.pc as i64);
        self.set_reg(inst.rd, val);
    }

    fn add(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1).wrapping_add(self.get_reg(inst.rs2));
        self.set_reg(inst.rd, val);
    }

    fn sub(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1).wrapping_sub(self.get_reg(inst.rs2));
        self.set_reg(inst.rd, val);
    }

    fn slt(&mut self, inst: EncodingR) {
        self.set_reg(inst.rd, (self.get_reg(inst.rs1) < self.get_reg(inst.rs2)) as i64);
    }

    fn sltu(&mut self, inst: EncodingR) {
        self.set_reg(inst.rd, ((self.get_reg(inst.rs1) as u64) < (self.get_reg(inst.rs2) as u64)) as i64);
    }

    fn xor(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1) ^ self.get_reg(inst.rs2);
        self.set_reg(inst.rd, val);
    }

    fn or(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1) | self.get_reg(inst.rs2);
        self.set_reg(inst.rd, val);
    }

    fn and(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1) & self.get_reg(inst.rs2);
        self.set_reg(inst.rd, val);
    }

    fn sll(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1).wrapping_shl(self.get_reg(inst.rs2) as u32);
        self.set_reg(inst.rd, val);
    }

    fn srl(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as u64).wrapping_shr(self.get_reg(inst.rs2) as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn sra(&mut self, inst: EncodingR) {
        let val = self.get_reg(inst.rs1).wrapping_shr(self.get_reg(inst.rs2) as u32);
        self.set_reg(inst.rd, val);
    }

    fn addw(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_add(self.get_reg(inst.rs2) as i32);
        self.set_reg(inst.rd, val as i64);
    }

    fn subw(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_sub(self.get_reg(inst.rs2) as i32);
        self.set_reg(inst.rd, val as i64);
    }

    fn sllw(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_shl(self.get_reg(inst.rs2) as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn srlw(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as u32).wrapping_shr(self.get_reg(inst.rs2) as u32) as i32;
        self.set_reg(inst.rd, val as i64);
    }

    fn sraw(&mut self, inst: EncodingR) {
        let val = (self.get_reg(inst.rs1) as i32).wrapping_shr(self.get_reg(inst.rs2) as u32);
        self.set_reg(inst.rd, val as i64);
    }

    fn jal(&mut self, inst: EncodingJ) {
        let target = self.pc.wrapping_add(inst.imm as u64);
        self.set_reg(inst.rd, self.pc.wrapping_add(4) as i64);
        self.pc = target;
    }

    fn jalr(&mut self, inst: EncodingI) {
        let target = (self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64) & !(1 as u64);
        self.set_reg(inst.rd, self.pc.wrapping_add(4) as i64);
        self.pc = target;
    }

    fn beq(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if self.get_reg(inst.rs1) == self.get_reg(inst.rs2) {
            self.pc = target;
        }
    }

    fn bne(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if self.get_reg(inst.rs1) != self.get_reg(inst.rs2) {
            self.pc = target;
        }
    }

    fn blt(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if self.get_reg(inst.rs1) < self.get_reg(inst.rs2) {
            self.pc = target;
        }
    }

    fn bge(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if self.get_reg(inst.rs1) >= self.get_reg(inst.rs2) {
            self.pc = target;
        }
    }

    fn bltu(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if (self.get_reg(inst.rs1) as u64) < (self.get_reg(inst.rs2) as u64) {
            self.pc = target;
        }
    }

    fn bgeu(&mut self, inst: EncodingB) {
        let target = self.pc.wrapping_add(inst.imm as u64);

        if (self.get_reg(inst.rs1) as u64) >= (self.get_reg(inst.rs2) as u64) {
            self.pc = target;
        }
    }

    fn lb(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load8(addr)? as i8;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn lbu(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load8(addr)? as u64;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn lh(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load16(addr)? as i16;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn lhu(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load16(addr)? as u64;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn lw(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load32(addr)? as i32;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn lwu(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load32(addr)? as u64;
        self.set_reg(inst.rd, val as i64);
        Ok(())
    }

    fn ld(&mut self, inst: EncodingI) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.mem.load64(addr)? as i64;
        self.set_reg(inst.rd, val);
        Ok(())
    }

    fn sb(&mut self, inst: EncodingS) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.get_reg(inst.rs2) as u8;
        self.mem.store8(addr, val)
    }

    fn sh(&mut self, inst: EncodingS) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.get_reg(inst.rs2) as u16;
        self.mem.store16(addr, val)
    }

    fn sw(&mut self, inst: EncodingS) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.get_reg(inst.rs2) as u32;
        self.mem.store32(addr, val)
    }

    fn sd(&mut self, inst: EncodingS) -> Result<(), Exception> {
        let addr = self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64;

        let val = self.get_reg(inst.rs2) as u64;
        self.mem.store64(addr, val)
    }

    fn ecall(&mut self, inst: EncodingI) {
        unimplemented!();
    }

    fn ebreak(&mut self, inst: EncodingI) {
        panic!("EBREAK");
    }

    fn mret(&mut self, inst: EncodingI) {
        unimplemented!();
    }

    fn csrrw(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        let rs1 = self.get_reg(inst.rs1);
        if inst.rd != 0 {
            let csr_val = self.csr.read(addr);
            self.set_reg(inst.rd, csr_val as i64);
        }
        self.csr.write(addr, rs1 as u64);
    }

    fn csrrs(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        let rs1 = self.get_reg(inst.rs1);
        let csr_val = self.csr.read(addr);
        self.set_reg(inst.rd, csr_val as i64);
        if inst.rs1 != 0 {
            self.csr.write(addr, csr_val | (rs1 as u64));
        }
    }

    fn csrrc(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        let rs1 = self.get_reg(inst.rs1);
        let csr_val = self.csr.read(addr);
        self.set_reg(inst.rd, csr_val as i64);
        if inst.rs1 != 0 {
            self.csr.write(addr, csr_val & !(rs1 as u64));
        }
    }

    fn csrrwi(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        if inst.rd != 0 {
            let csr_val = self.csr.read(addr);
            self.set_reg(inst.rd, csr_val as i64);
        }
        self.csr.write(addr, inst.rs1 as u64);
    }

    fn csrrsi(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        let csr_val = self.csr.read(addr);
        self.set_reg(inst.rd, csr_val as i64);
        if inst.rs1 != 0 {
            self.csr.write(addr, csr_val | (inst.rs1 as u64));
        }
    }

    fn csrrci(&mut self, inst: EncodingI) {
        let addr = (inst.imm as u16) & 0xfff;
        let csr_val = self.csr.read(addr);
        self.set_reg(inst.rd, csr_val as i64);
        if inst.rs1 != 0 {
            self.csr.write(addr, csr_val & !(inst.rs1 as u64));
        }
    }
}
