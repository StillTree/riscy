pub struct MStatus {
    bits: u64,
}

impl MStatus {
    const MIE_SHIFT: usize = 3;
    const MPIE_SHIFT: usize = 7;
    const MPP_SHIFT: usize = 11;

    const M_WRITE_MASK: u64 = (1 << Self::MIE_SHIFT) | (1 << Self::MPIE_SHIFT) | (3 << Self::MPP_SHIFT);
    const M_READ_MASK: u64 = Self::M_WRITE_MASK;

    pub fn mie(&self) -> bool {
        ((self.bits >> Self::MIE_SHIFT) & 1) != 0
    }

    pub fn set_mie(&mut self, val: bool) {
        if val {
            self.bits |= 1 << Self::MIE_SHIFT;
        } else {
            self.bits &= !(1 << Self::MIE_SHIFT);
        }
    }

    pub fn mpie(&self) -> bool {
        ((self.bits >> Self::MPIE_SHIFT) & 1) != 0
    }

    pub fn set_mpie(&mut self, val: bool) {
        if val {
            self.bits |= 1 << Self::MPIE_SHIFT;
        } else {
            self.bits &= !(1 << Self::MPIE_SHIFT);
        }
    }

    pub fn mpp(&self) -> u8 {
        ((self.bits >> Self::MPIE_SHIFT) & 3) as u8
    }

    pub fn set_mpp(&mut self, val: u8) {
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

pub struct CsrState {
    mstatus: MStatus,
    mcause: u64,
    mepc: u64,
    mtvec: u64,
    mnstatus: u64,
}
