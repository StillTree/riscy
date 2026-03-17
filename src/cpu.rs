pub enum PrivMode {
    Machine = 0b11,
    Supervisor = 0b01,
    User = 0b00,
}

struct Cpu {
    mem: [u8; 4096],
    reg: [i64; 32],
    pc: u64,
}

impl Cpu {
    pub fn new() -> Self {
        Cpu {
            reg: [0; 32],
            mem: [0; 4096],
            pc: 0,
        }
    }

    fn set_reg(self: &mut Cpu, reg: usize, val: i64) {
        if reg == 0 {
            return;
        }

        self.reg[reg] = val;
    }

    fn get_reg(self: &Cpu, reg: usize) -> i64 {
        self.reg[reg]
    }

    pub fn step(self: &mut Cpu) {}
}
