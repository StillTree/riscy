use crate::{
    bin_loader,
    cpu::Cpu,
    csr::CsrState,
    dev::{Bus, MemRegion, htif::Htif},
    scheduler::Scheduler,
};

pub struct Machine {
    cpu: Cpu,
    bus: Bus,
    sched: Scheduler,
    cur_cycle: u64,
}

impl Machine {
    pub fn new() -> Self {
        let mut bus = Bus {
            regions: vec![
                MemRegion::new_ram(0x80000000, 0x1000),
                MemRegion::new_mmio(0x80001000, 8, Box::new(Htif::new())),
                MemRegion::new_ram(0x80001008, 0x2ff8),
            ],
        };

        let mut sched = Scheduler::new();

        let bin_info = bin_loader::load_elf("../riscv-tests/isa/rv64ui-p-addi", &mut bus, &mut sched).unwrap();

        let mut cpu = Cpu::new(CsrState::new());
        cpu.pc = bin_info.entry;

        Machine {
            bus,
            cpu,
            sched,
            cur_cycle: 0,
        }
    }

    pub fn run(&mut self) {
        println!(
            "Starting the machine at cycle 0, with next_deadline at {}",
            self.sched.next_deadline()
        );

        loop {
            println!("Trying to service devices at cycle {}", self.cur_cycle);
            self.sched.service_due(self.cur_cycle);

            while self.cur_cycle < self.sched.next_deadline() {
                println!("Executing cycle {}", self.cur_cycle);

                // TODO: See if the bus can somehow reference the cycle and scheduler differently to
                // avoid the massive funciton parameter cascade
                self.cpu.step(&mut self.bus, self.cur_cycle, &mut self.sched);
                self.cur_cycle += 1;

                if self.cur_cycle > 1000 {
                    return;
                }
            }

            println!("Deadline reached");
        }
    }
}
