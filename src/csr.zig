const CsrState = struct {
    mstatus: u64,
    misa: u64,

    pub fn writeCsr(self: *CsrState, csrAddr: CsrAddr, val: u64) !void {
    }
};

const CsrAddr = enum(u12) {
    mstatus = 0x300,
    mtvec = 0x305,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mtval2 = 0x34b,
    misa = 0x301,
    mvendorid = 0xf11,
};
