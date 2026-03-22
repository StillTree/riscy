use crate::{
    csr::CsrState,
    dev::Bus,
    exception::{Exception, TrapCause},
    instructions::{BaseInst, EncodingB, EncodingI, EncodingIShifts, EncodingJ, EncodingR, EncodingS, EncodingU, Inst, ZicsrInst},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivMode {
    Machine = 0b11,
    Supervisor = 0b01,
    User = 0b00,
}

pub struct Cpu {
    mem: Bus,
    csr: CsrState,
    reg: [i64; 32],
    pub pc: u64,
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

    fn set_reg(&mut self, reg: u8, val: i64) {
        if reg == 0 {
            return;
        }

        self.reg[reg as usize] = val;
    }

    fn get_reg(&self, reg: u8) -> i64 {
        self.reg[reg as usize]
    }

    fn handle_trap(&mut self, cause: TrapCause) {
        self.pc = self.csr.handle_trap(cause, self.pc);
    }

    fn handle_trap_exit(&mut self) {
        self.pc = self.csr.handle_trap_exit();
    }

    pub fn step(self: &mut Cpu) {
        let prev_pc = self.pc;

        let inst = match self.mem.load32(self.pc) {
            Ok(inst) => Inst::decode(inst),
            Err(_) => {
                self.handle_trap(TrapCause::Exception(Exception::InstAccessFault));
                return;
            }
        };

        std::println!("Executing at {:x}: {:?}", self.pc, inst);

        match self.exec_inst(inst) {
            Err(e) => {
                self.handle_trap(TrapCause::Exception(e));
            }
            Ok(_) => {
                if prev_pc == self.pc {
                    self.pc = self.pc.wrapping_add(4);
                }
            }
        };
    }
}

impl Cpu {
    fn exec_inst(&mut self, inst: Inst) -> Result<(), Exception> {
        match inst {
            Inst::Base(base) => self.exec_base_inst(base),
            Inst::Zicsr(zicsr) => self.exec_zicsr_inst(zicsr),
        }
    }

    fn exec_base_inst(&mut self, inst: BaseInst) -> Result<(), Exception> {
        match inst {
            BaseInst::Addi(e) => Ok(self.addi(e)),
            BaseInst::Slti(e) => Ok(self.slti(e)),
            BaseInst::Sltiu(e) => Ok(self.sltiu(e)),
            BaseInst::Xori(e) => Ok(self.xori(e)),
            BaseInst::Ori(e) => Ok(self.ori(e)),
            BaseInst::Andi(e) => Ok(self.andi(e)),
            BaseInst::Slli(e) => Ok(self.slli(e)),
            BaseInst::Srai(e) => Ok(self.srai(e)),
            BaseInst::Srli(e) => Ok(self.srli(e)),
            BaseInst::Addiw(e) => Ok(self.addiw(e)),
            BaseInst::Slliw(e) => Ok(self.slliw(e)),
            BaseInst::Sraiw(e) => Ok(self.sraiw(e)),
            BaseInst::Srliw(e) => Ok(self.srliw(e)),
            BaseInst::Lui(e) => Ok(self.lui(e)),
            BaseInst::Auipc(e) => Ok(self.auipc(e)),
            BaseInst::Add(e) => Ok(self.add(e)),
            BaseInst::Sub(e) => Ok(self.sub(e)),
            BaseInst::Slt(e) => Ok(self.slt(e)),
            BaseInst::Sltu(e) => Ok(self.sltu(e)),
            BaseInst::Xor(e) => Ok(self.xor(e)),
            BaseInst::Or(e) => Ok(self.or(e)),
            BaseInst::And(e) => Ok(self.and(e)),
            BaseInst::Sll(e) => Ok(self.sll(e)),
            BaseInst::Srl(e) => Ok(self.srl(e)),
            BaseInst::Sra(e) => Ok(self.sra(e)),
            BaseInst::Addw(e) => Ok(self.addw(e)),
            BaseInst::Subw(e) => Ok(self.subw(e)),
            BaseInst::Sllw(e) => Ok(self.sllw(e)),
            BaseInst::Srlw(e) => Ok(self.srlw(e)),
            BaseInst::Sraw(e) => Ok(self.sraw(e)),
            BaseInst::Jal(e) => Ok(self.jal(e)),
            BaseInst::Jalr(e) => Ok(self.jalr(e)),
            BaseInst::Beq(e) => Ok(self.beq(e)),
            BaseInst::Bne(e) => Ok(self.bne(e)),
            BaseInst::Blt(e) => Ok(self.blt(e)),
            BaseInst::Bge(e) => Ok(self.bge(e)),
            BaseInst::Bltu(e) => Ok(self.bltu(e)),
            BaseInst::Bgeu(e) => Ok(self.bgeu(e)),
            BaseInst::Lb(e) => self.lb(e),
            BaseInst::Lbu(e) => self.lbu(e),
            BaseInst::Lh(e) => self.lh(e),
            BaseInst::Lhu(e) => self.lhu(e),
            BaseInst::Lw(e) => self.lw(e),
            BaseInst::Lwu(e) => self.lwu(e),
            BaseInst::Ld(e) => self.ld(e),
            BaseInst::Sb(e) => self.sb(e),
            BaseInst::Sh(e) => self.sh(e),
            BaseInst::Sw(e) => self.sw(e),
            BaseInst::Sd(e) => self.sd(e),
            BaseInst::Fence(()) => Ok(()),
            BaseInst::Ecall(e) => Ok(self.ecall(e)),
            BaseInst::Ebreak(e) => Ok(self.ebreak(e)),
            BaseInst::Mret(e) => Ok(self.mret(e)),
        }
    }

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
        let target = (self.get_reg(inst.rs1).wrapping_add(inst.imm) as u64) & !1u64;
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

    fn ecall(&mut self, _: EncodingI) {
        self.handle_trap(TrapCause::Exception(Exception::EcallFromMachine));
    }

    fn ebreak(&mut self, _: EncodingI) {
        panic!("EBREAK");
    }

    fn mret(&mut self, _: EncodingI) {
        self.handle_trap_exit();
    }

    fn exec_zicsr_inst(&mut self, zicsr: ZicsrInst) -> Result<(), Exception> {
        match zicsr {
            ZicsrInst::Csrrw(e) => Ok(self.csrrw(e)),
            ZicsrInst::Csrrs(e) => Ok(self.csrrs(e)),
            ZicsrInst::Csrrc(e) => Ok(self.csrrc(e)),
            ZicsrInst::Csrrwi(e) => Ok(self.csrrwi(e)),
            ZicsrInst::Csrrsi(e) => Ok(self.csrrsi(e)),
            ZicsrInst::Csrrci(e) => Ok(self.csrrci(e)),
        }
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
