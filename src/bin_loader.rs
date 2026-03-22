use std::fs;

use goblin::elf::{Elf, program_header};

use crate::dev::Bus;

pub struct BinInfo {
    pub entry: u64,
}

pub fn load_elf(filename: &str, bus: &mut Bus) -> Result<BinInfo, Box<dyn std::error::Error>> {
    let buffer = fs::read(filename)?;
    let elf = Elf::parse(&buffer)?;

    for prog_header in elf.program_headers {
        if prog_header.p_type != program_header::PT_LOAD {
            continue;
        }

        let addr = prog_header.p_vaddr;
        let file_offset = prog_header.p_offset as usize;
        let file_size = prog_header.p_filesz as usize;
        // let mem_size = prog_header.p_memsz as usize;

        let segment_data = &buffer[file_offset..file_offset + file_size];

        for (i, &byte) in segment_data.iter().enumerate() {
            bus.store8(addr + (i as u64), byte).unwrap();
        }
    }

    Ok(BinInfo { entry: elf.entry })
}
