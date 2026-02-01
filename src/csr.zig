const cpu = @import("cpu.zig");

pub const Status = struct {
    // TODO: Move somewhere else?
    // pub const SIE_SHIFT = 1;
    pub const MIE_SHIFT = 3;
    // pub const SPIE_SHIFT = 5;
    // pub const UBE_SHIFT = 6;
    pub const MPIE_SHIFT = 7;
    // pub const SPP_SHIFT = 8;
    // pub const VS_SHIFT = 9;
    pub const MPP_SHIFT = 11;
    // pub const FS_SHIFT = 13;
    // pub const XS_SHIFT = 15;
    // pub const MPRV_SHIFT = 17;
    // pub const SUM_SHIFT = 18;
    // pub const MXR_SHIFT = 19;
    // pub const TVM_SHIFT = 20;
    // pub const TW_SHIFT = 21;
    // pub const TSR_SHIFT = 22;
    // pub const SDELP_SHIFT = 23;
    // pub const SDT_SHIFT = 24;
    // pub const UXL_SHIFT = 32;
    // pub const SXL_SHIFT = 34;
    // pub const SBE_SHIFT = 36;
    // pub const MBE_SHIFT = 37;
    // pub const GVA_SHIFT = 38;
    // pub const MPV_SHIFT = 39;
    // pub const MPELP_SHIFT = 41;
    // pub const MDT_SHIFT = 42;
    // pub const SD_SHIFT = 63;

    // TODO: Feature flags that will enable extensions and generate this on startup
    const MSTATUS_READ_MASK = (1 << MIE_SHIFT) | (1 << MPIE_SHIFT) | (3 << MPP_SHIFT);
    const MSTATUS_WRITE_MASK = (1 << MIE_SHIFT) | (1 << MPIE_SHIFT) | (3 << MPP_SHIFT);
    const SSTATUS_READ_MASK = 1;
    const SSTATUS_WRITE_MASK = 1;
    const USTATUS_READ_MASK = 1;
    const USTATUS_WRITE_MASK = 1;

    val: u64,

    pub fn init() Status {
        return .{
            .val = 0,
        };
    }

    inline fn writeMask(priv: cpu.Priv) u64 {
        return switch (priv) {
            .machine => MSTATUS_WRITE_MASK,
            .supervisor => SSTATUS_WRITE_MASK,
            .user => USTATUS_WRITE_MASK,
        };
    }

    inline fn readMask(priv: cpu.Priv) u64 {
        return switch (priv) {
            .machine => MSTATUS_READ_MASK,
            .supervisor => SSTATUS_READ_MASK,
            .user => USTATUS_READ_MASK,
        };
    }

    pub fn read(self: *const Status, priv: cpu.Priv) u64 {
        return self.val & readMask(priv);
    }

    pub fn write(self: *Status, newVal: u64, priv: cpu.Priv) void {
        const mask = writeMask(priv);
        self.val = (self.val & ~mask) | (newVal & mask);
    }
};

pub const Cause = enum(u64) {
    inst_addr_misalign = 0,
    inst_access_fault = 1,
    illegal_inst = 2,
    breakpoint = 3,
    load_addr_misalign = 4,
    load_access_fault = 5,
    store_amo_addr_misalign = 6,
    store_amo_access_fault = 7,
    ecall_from_user = 8,
    ecall_from_supervisor = 9,
    ecall_from_machine = 11,
    inst_page_fault = 12,
    load_page_fault = 13,
    store_amo_page_fault = 15,
    double_trap = 16,
    software_check = 18,
    hardware_error = 19,
};

pub const MtvecMode = enum(u2) {
    direct = 0b00,
    vectored = 0b01,
};

pub const Addr = enum(u12) {
    mstatus = 0x300,
    mtvec = 0x305,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mtval2 = 0x34b,
    misa = 0x301,
    mvendorid = 0xf11,
    mhartid = 0xf14,
    mnstatus = 0x744,
    pmpcfg0 = 0x3a0,
    pmpaddr0 = 0x3b0,
    mie = 0x304,
    satp = 0x180,
    medeleg = 0x302,
    mideleg = 0x303,
};

pub const State = struct {
    status: Status,
    mcause: Cause,
    mepc: u64,
    mtvec: u64,
    mnstatus: u64,

    pub fn init() State {
        return .{
            .status = Status.init(),
            .mcause = .hardware_error,
            .mepc = 0,
            .mtvec = 0,
            .mnstatus = 0,
        };
    }

    pub fn write(self: *State, csrAddr: Addr, val: u64) !void {
        switch (csrAddr) {
            .satp, .pmpaddr0, .pmpcfg0, .mie, .medeleg, .mideleg => {},
            .mstatus => self.status.write(val, cpu.Priv.machine),
            .mtvec => {
                self.mtvec = val;
            },
            .mcause => {
                self.mcause = @enumFromInt(val);
            },
            .mepc => {
                self.mepc = val;
            },
            .mnstatus => {
                self.mnstatus = val;
            },
            else => return error.CsrWriteUnimplemented,
        }
    }

    pub fn read(self: *State, csrAddr: Addr) !u64 {
        return switch (csrAddr) {
            .misa, .mhartid, .satp => 0,
            .mstatus => self.status.read(cpu.Priv.machine),
            .mtvec => self.mtvec,
            .mcause => @intFromEnum(self.mcause),
            .mepc => self.mepc,
            .mnstatus => self.mnstatus,
            else => error.CsrReadUnimplemented,
        };
    }
};
