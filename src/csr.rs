use crate::exception::TrapCause;

pub struct MStatus {
    bits: u64,
}

impl MStatus {
    const MIE_SHIFT: usize = 3;
    const MPIE_SHIFT: usize = 7;
    const MPP_SHIFT: usize = 11;

    const M_WRITE_MASK: u64 = (1 << Self::MIE_SHIFT) | (1 << Self::MPIE_SHIFT) | (3 << Self::MPP_SHIFT);
    const M_READ_MASK: u64 = Self::M_WRITE_MASK;

    fn mie(&self) -> bool {
        ((self.bits >> Self::MIE_SHIFT) & 1) != 0
    }

    fn set_mie(&mut self, val: bool) {
        if val {
            self.bits |= 1 << Self::MIE_SHIFT;
        } else {
            self.bits &= !(1 << Self::MIE_SHIFT);
        }
    }

    fn mpie(&self) -> bool {
        ((self.bits >> Self::MPIE_SHIFT) & 1) != 0
    }

    fn set_mpie(&mut self, val: bool) {
        if val {
            self.bits |= 1 << Self::MPIE_SHIFT;
        } else {
            self.bits &= !(1 << Self::MPIE_SHIFT);
        }
    }

    fn mpp(&self) -> u8 {
        ((self.bits >> Self::MPIE_SHIFT) & 3) as u8
    }

    fn set_mpp(&mut self, val: u8) {
        self.bits &= !(3 << Self::MPP_SHIFT);
        self.bits |= (val as u64 & 3) << Self::MPP_SHIFT;
    }

    pub fn write_m(&mut self, val: u64) {
        self.bits = (self.bits & !Self::M_WRITE_MASK) | (val & Self::M_WRITE_MASK);
    }

    pub fn read_m(&self) -> u64 {
        self.bits & Self::M_READ_MASK
    }
}

pub mod addr {
    pub const MSTATUS: u16 = 0x300;
    pub const MTVEC: u16 = 0x305;
    pub const MEPC: u16 = 0x341;
    pub const MCAUSE: u16 = 0x342;
    pub const MTVAL: u16 = 0x343;
    pub const MTVAL2: u16 = 0x34b;
    pub const MISA: u16 = 0x301;
    pub const MVENDORID: u16 = 0xf11;
    pub const MHARTID: u16 = 0xf14;
    pub const MNSTATUS: u16 = 0x744;
    pub const PMPCFG0: u16 = 0x3a0;
    pub const PMPADDR0: u16 = 0x3b0;
    pub const MIE: u16 = 0x304;
    pub const SATP: u16 = 0x180;
    pub const MEDELEG: u16 = 0x302;
    pub const MIDELEG: u16 = 0x303;
}

pub struct CsrState {
    mstatus: MStatus,
    mcause: u64,
    mepc: u64,
    mtvec: u64,
    mnstatus: u64,
}

impl CsrState {
    pub fn new() -> Self {
        Self {
            mstatus: MStatus {
                bits: 0,
            },
            mepc: 0,
            mcause: 0,
            mtvec: 0,
            mnstatus: 0,
        }
    }

    pub fn write(&mut self, addr: u16, val: u64) {
        match addr {
            addr::SATP | addr::PMPADDR0 | addr::PMPCFG0 | addr::MIE | addr::MEDELEG | addr::MIDELEG => {}
            addr::MSTATUS => self.mstatus.write_m(val),
            addr::MTVEC => self.mtvec = val,
            addr::MCAUSE => self.mcause = val,
            addr::MEPC => self.mepc = val,
            addr::MNSTATUS => self.mnstatus = val,
            _ => panic!("Unknown csr addr"),
        }
    }

    pub fn read(&self, addr: u16) -> u64 {
        match addr {
            addr::MSTATUS => self.mstatus.read_m(),
            addr::MISA | addr::MHARTID | addr::SATP => 0,
            addr::MTVEC => self.mtvec,
            addr::MCAUSE => self.mcause,
            addr::MEPC => self.mepc,
            addr::MNSTATUS => self.mnstatus,
            _ => panic!("Unknown csr addr"),
        }
    }

    pub fn handle_trap(&mut self, cause: TrapCause, cur_pc: u64) -> u64 {
        // TODO: Finish this, it's obviously missing a lot
        let mie = self.mstatus.mie();
        self.mstatus.set_mpie(mie);
        self.mstatus.set_mie(false);

        self.mcause = cause.code();
        self.mepc = cur_pc;

        let mtvec = self.mtvec;
        if (mtvec & 3) != 0 {
            panic!();
        }

        mtvec & !3u64
    }

    pub fn handle_trap_exit(&mut self) -> u64 {
        // TODO: Finish this
        let mpie = self.mstatus.mpie();
        self.mstatus.set_mie(mpie);

        self.mepc
    }
}
