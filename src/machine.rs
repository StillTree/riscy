use crate::{
    bin_loader,
    cpu::Cpu,
    csr::CsrState,
    dev::{Bus, MemRegion},
};

pub struct Machine {
    cpu: Cpu,
    bus: Bus,
    cycle_count: u64,
}

impl Machine {
    pub fn new() -> Self {
        let mut bus = Bus {
            regions: vec![MemRegion::new_ram(0x80000000, 0x4000)],
        };

        let bin_info = bin_loader::load_elf("../riscv-tests/isa/rv64ui-p-addi", &mut bus).unwrap();

        let mut cpu = Cpu::new(CsrState::new());
        cpu.pc = bin_info.entry;

        Machine { bus, cpu, cycle_count: 0 }
    }

    pub fn run(&mut self) {
        loop {
            self.cpu.step(&mut self.bus);
            self.cycle_count += 1;
        }
    }
}
