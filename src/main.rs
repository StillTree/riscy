use riscy::{
    bin_loader, cpu,
    csr::CsrState,
    dev::{Bus, MemRegion},
};

fn main() {
    let mut mem_bus = Bus {
        regions: vec![MemRegion::new_ram(0x80000000, 0x4000)],
    };

    let bin_info = bin_loader::load_elf("../riscv-tests/isa/rv64ui-p-addi", &mut mem_bus).unwrap();

    let csr_state = CsrState::new();

    let mut cpu = cpu::Cpu::new(mem_bus, csr_state);
    cpu.pc = bin_info.entry;

    loop {
        cpu.step();
    }
}
