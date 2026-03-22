#[derive(Debug, PartialEq, Eq)]
pub struct EncodingS {
    pub rs1: u8,
    pub rs2: u8,
    pub imm: i64,
}

impl EncodingS {
    pub fn new(inst: u32) -> Self {
        let rs1 = ((inst >> 15) & 0x1F) as u8;
        let rs2 = ((inst >> 20) & 0x1F) as u8;

        let bits_11_5 = (inst >> 25) & 0x7F;
        let bits_4_0 = (inst >> 7) & 0x1F;

        let res = (bits_11_5 << 5) | bits_4_0;

        let imm = ((res as i64) << 52) >> 52;

        Self { rs1, rs2, imm }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingB {
    pub rs1: u8,
    pub rs2: u8,
    pub imm: i64,
}

impl EncodingB {
    pub fn new(inst: u32) -> Self {
        let rs1 = ((inst >> 15) & 0x1F) as u8;
        let rs2 = ((inst >> 20) & 0x1F) as u8;

        let bit_12 = (inst >> 31) & 0x1;
        let bit_11 = (inst >> 7) & 0x1;
        let bits_10_5 = (inst >> 25) & 0x3F;
        let bits_4_1 = (inst >> 8) & 0xF;

        let res = (bit_12 << 12) | (bit_11 << 11) | (bits_10_5 << 5) | (bits_4_1 << 1);

        let imm = ((res as i64) << 51) >> 51;

        Self { rs1, rs2, imm }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingJ {
    pub rd: u8,
    pub imm: i64,
}

impl EncodingJ {
    pub fn new(inst: u32) -> Self {
        let rd = ((inst >> 7) & 0x1f) as u8;

        let bit_20 = (inst >> 31) & 0x1;
        let bits_10_1 = (inst >> 21) & 0x3ff;
        let bit_11 = (inst >> 20) & 0x1;
        let bits_19_12 = (inst >> 12) & 0xff;

        let res = (bit_20 << 20) | (bits_19_12 << 12) | (bit_11 << 11) | (bits_10_1 << 1);

        let imm = ((res as i64) << 43) >> 43;

        Self { rd, imm }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingI {
    pub rd: u8,
    pub rs1: u8,
    pub imm: i64,
}

impl EncodingI {
    pub fn new(inst: u32) -> Self {
        Self {
            rd: ((inst >> 7) & 0x1f) as u8,
            rs1: ((inst >> 15) & 0x1f) as u8,
            imm: ((inst as i32) >> 20) as i64,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingIShifts {
    pub rd: u8,
    pub rs1: u8,
    pub shamt: u8,
    pub imm: i64,
}

impl EncodingIShifts {
    pub fn new(inst: u32) -> Self {
        Self {
            rd: ((inst >> 7) & 0x1f) as u8,
            rs1: ((inst >> 15) & 0x1f) as u8,
            shamt: ((inst >> 20) & 0x3f) as u8,
            imm: ((inst as i32) >> 26) as i64,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingU {
    pub rd: u8,
    pub imm: i64,
}

impl EncodingU {
    pub fn new(inst: u32) -> Self {
        Self {
            rd: ((inst >> 7) & 0x1f) as u8,
            imm: ((inst as i32) & !0xfff) as i64,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub struct EncodingR {
    pub rd: u8,
    pub rs1: u8,
    pub rs2: u8,
}

impl EncodingR {
    pub fn new(inst: u32) -> Self {
        Self {
            rd: ((inst >> 7) & 0x1f) as u8,
            rs1: ((inst >> 15) & 0x1f) as u8,
            rs2: ((inst >> 20) & 0x1f) as u8,
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum BaseInst {
    Addi(EncodingI),
    Slti(EncodingI),
    Sltiu(EncodingI),
    Xori(EncodingI),
    Ori(EncodingI),
    Andi(EncodingI),
    Slli(EncodingIShifts),
    Srai(EncodingIShifts),
    Srli(EncodingIShifts),
    Addiw(EncodingI),
    Slliw(EncodingIShifts),
    Sraiw(EncodingIShifts),
    Srliw(EncodingIShifts),
    Lui(EncodingU),
    Auipc(EncodingU),
    Add(EncodingR),
    Sub(EncodingR),
    Slt(EncodingR),
    Sltu(EncodingR),
    Xor(EncodingR),
    Or(EncodingR),
    And(EncodingR),
    Sll(EncodingR),
    Srl(EncodingR),
    Sra(EncodingR),
    Addw(EncodingR),
    Subw(EncodingR),
    Sllw(EncodingR),
    Srlw(EncodingR),
    Sraw(EncodingR),
    Jal(EncodingJ),
    Jalr(EncodingI),
    Beq(EncodingB),
    Bne(EncodingB),
    Blt(EncodingB),
    Bge(EncodingB),
    Bltu(EncodingB),
    Bgeu(EncodingB),
    Lb(EncodingI),
    Lbu(EncodingI),
    Lh(EncodingI),
    Lhu(EncodingI),
    Lw(EncodingI),
    Lwu(EncodingI),
    Ld(EncodingI),
    Sb(EncodingS),
    Sh(EncodingS),
    Sw(EncodingS),
    Sd(EncodingS),
    Fence(()),
    Ecall(EncodingI),
    Ebreak(EncodingI),
    Mret(EncodingI),
}

#[derive(Debug, PartialEq, Eq)]
pub enum ZicsrInst {
    Csrrw(EncodingI),
    Csrrs(EncodingI),
    Csrrc(EncodingI),
    Csrrwi(EncodingI),
    Csrrsi(EncodingI),
    Csrrci(EncodingI),
}

#[derive(Debug, PartialEq, Eq)]
pub enum Inst {
    Base(BaseInst),
    Zicsr(ZicsrInst),
}

mod op {
    pub const IMM: u8 = 0b0010011;
    pub const IMM32: u8 = 0b0011011;
    pub const LUI: u8 = 0b0110111;
    pub const AUIPC: u8 = 0b0010111;
    pub const OP: u8 = 0b0110011;
    pub const OP32: u8 = 0b0111011;
    pub const JAL: u8 = 0b1101111;
    pub const JALR: u8 = 0b1100111;
    pub const BRANCH: u8 = 0b1100011;
    pub const LOAD: u8 = 0b0000011;
    pub const STORE: u8 = 0b0100011;
    pub const MISC_MEM: u8 = 0b0001111;
    pub const SYSTEM: u8 = 0b1110011;
}

impl Inst {
    pub fn decode(inst: u32) -> Self {
        let opcode = (inst & 0x7f) as u8;

        let funct3 = ((inst >> 12) & 0x7) as u8;
        let funct7 = ((inst >> 25) & 0x7f) as u8;

        match opcode {
            op::IMM => match funct3 {
                0b000 => Inst::Base(BaseInst::Addi(EncodingI::new(inst))),
                0b010 => Inst::Base(BaseInst::Slti(EncodingI::new(inst))),
                0b011 => Inst::Base(BaseInst::Sltiu(EncodingI::new(inst))),
                0b100 => Inst::Base(BaseInst::Xori(EncodingI::new(inst))),
                0b110 => Inst::Base(BaseInst::Ori(EncodingI::new(inst))),
                0b111 => Inst::Base(BaseInst::Andi(EncodingI::new(inst))),
                0b001 => Inst::Base(BaseInst::Slli(EncodingIShifts::new(inst))),
                0b101 => {
                    let spec = EncodingIShifts::new(inst);

                    if spec.imm == 0x10 {
                        Inst::Base(BaseInst::Srai(spec))
                    } else {
                        Inst::Base(BaseInst::Srli(spec))
                    }
                }
                _ => panic!("Unknown inst"),
            },
            op::IMM32 => match funct3 {
                0b000 => Inst::Base(BaseInst::Addiw(EncodingI::new(inst))),
                0b001 => Inst::Base(BaseInst::Slliw(EncodingIShifts::new(inst))),
                0b101 => {
                    let spec = EncodingIShifts::new(inst);

                    if spec.imm == 0x10 {
                        Inst::Base(BaseInst::Sraiw(spec))
                    } else {
                        Inst::Base(BaseInst::Srliw(spec))
                    }
                }
                _ => panic!("Unknown inst"),
            },
            op::LUI => Inst::Base(BaseInst::Lui(EncodingU::new(inst))),
            op::AUIPC => Inst::Base(BaseInst::Auipc(EncodingU::new(inst))),
            op::OP => match (funct3, funct7) {
                (0b000, 0x0) => Inst::Base(BaseInst::Add(EncodingR::new(inst))),
                (0b000, 0x20) => Inst::Base(BaseInst::Sub(EncodingR::new(inst))),
                (0b010, 0x0) => Inst::Base(BaseInst::Slt(EncodingR::new(inst))),
                (0b011, 0x0) => Inst::Base(BaseInst::Sltu(EncodingR::new(inst))),
                (0b100, 0x0) => Inst::Base(BaseInst::Xor(EncodingR::new(inst))),
                (0b110, 0x0) => Inst::Base(BaseInst::Or(EncodingR::new(inst))),
                (0b111, 0x0) => Inst::Base(BaseInst::And(EncodingR::new(inst))),
                (0b001, 0x0) => Inst::Base(BaseInst::Sll(EncodingR::new(inst))),
                (0b101, 0x0) => Inst::Base(BaseInst::Srl(EncodingR::new(inst))),
                (0b101, 0x20) => Inst::Base(BaseInst::Sra(EncodingR::new(inst))),
                _ => panic!("Unknown inst"),
            },
            op::OP32 => match (funct3, funct7) {
                (0b000, 0x0) => Inst::Base(BaseInst::Addw(EncodingR::new(inst))),
                (0b000, 0x20) => Inst::Base(BaseInst::Subw(EncodingR::new(inst))),
                (0b001, 0x0) => Inst::Base(BaseInst::Sllw(EncodingR::new(inst))),
                (0b101, 0x0) => Inst::Base(BaseInst::Srlw(EncodingR::new(inst))),
                (0b101, 0x20) => Inst::Base(BaseInst::Sraw(EncodingR::new(inst))),
                _ => panic!("Unknown inst"),
            },
            op::JAL => Inst::Base(BaseInst::Jal(EncodingJ::new(inst))),
            op::JALR => Inst::Base(BaseInst::Jalr(EncodingI::new(inst))),
            op::BRANCH => match funct3 {
                0b000 => Inst::Base(BaseInst::Beq(EncodingB::new(inst))),
                0b001 => Inst::Base(BaseInst::Bne(EncodingB::new(inst))),
                0b100 => Inst::Base(BaseInst::Blt(EncodingB::new(inst))),
                0b101 => Inst::Base(BaseInst::Bge(EncodingB::new(inst))),
                0b110 => Inst::Base(BaseInst::Bltu(EncodingB::new(inst))),
                0b111 => Inst::Base(BaseInst::Bgeu(EncodingB::new(inst))),
                _ => panic!("Unknown inst"),
            },
            op::LOAD => match funct3 {
                0b000 => Inst::Base(BaseInst::Lb(EncodingI::new(inst))),
                0b100 => Inst::Base(BaseInst::Lbu(EncodingI::new(inst))),
                0b001 => Inst::Base(BaseInst::Lh(EncodingI::new(inst))),
                0b101 => Inst::Base(BaseInst::Lhu(EncodingI::new(inst))),
                0b010 => Inst::Base(BaseInst::Lw(EncodingI::new(inst))),
                0b110 => Inst::Base(BaseInst::Lwu(EncodingI::new(inst))),
                0b011 => Inst::Base(BaseInst::Ld(EncodingI::new(inst))),
                _ => panic!("Unknown inst"),
            },
            op::STORE => match funct3 {
                0b000 => Inst::Base(BaseInst::Sb(EncodingS::new(inst))),
                0b001 => Inst::Base(BaseInst::Sh(EncodingS::new(inst))),
                0b010 => Inst::Base(BaseInst::Sw(EncodingS::new(inst))),
                0b011 => Inst::Base(BaseInst::Sd(EncodingS::new(inst))),
                _ => panic!("Unknown inst"),
            },
            op::MISC_MEM => Inst::Base(BaseInst::Fence(())),
            op::SYSTEM => match funct3 {
                0b000 => {
                    let i = EncodingI::new(inst);

                    match i.imm {
                        0b0000000000 => Inst::Base(BaseInst::Ecall(i)),
                        0b0000000001 => Inst::Base(BaseInst::Ebreak(i)),
                        0b1100000010 => Inst::Base(BaseInst::Mret(i)),
                        _ => panic!("Unknown inst"),
                    }
                }
                0b001 => Inst::Zicsr(ZicsrInst::Csrrw(EncodingI::new(inst))),
                0b010 => Inst::Zicsr(ZicsrInst::Csrrs(EncodingI::new(inst))),
                0b011 => Inst::Zicsr(ZicsrInst::Csrrc(EncodingI::new(inst))),
                0b101 => Inst::Zicsr(ZicsrInst::Csrrwi(EncodingI::new(inst))),
                0b110 => Inst::Zicsr(ZicsrInst::Csrrsi(EncodingI::new(inst))),
                0b111 => Inst::Zicsr(ZicsrInst::Csrrci(EncodingI::new(inst))),
                _ => panic!("Unknown inst"),
            },
            _ => panic!("Unknown inst"),
        }
    }
}
