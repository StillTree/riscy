#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Exception {
    InstAddrMisalign = 0,
    InstAccessFault = 1,
    IllegalInst = 2,
    Breakpoint = 3,
    LoadAddrMisalign = 4,
    LoadAccessFault = 5,
    StoreAmoAddrMisalign = 6,
    StoreAmoAccessFault = 7,
    EcallFromUser = 8,
    EcallFromSupervisor = 9,
    EcallFromMachine = 11,
    InstPageFault = 12,
    LoadPageFault = 13,
    StoreAmoPageFault = 15,
    DoubleTrap = 16,
    SoftwareCheck = 18,
    HardwareError = 19,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrapCause {
    Exception(Exception),
    Interrupt(()),
}

impl TrapCause {
    pub fn code(self) -> u64 {
        match self {
            Self::Exception(e) => e as u64,
            Self::Interrupt(_) => unimplemented!(),
        }
    }
}
