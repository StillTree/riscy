use crate::cpu::Exception;

pub mod ram;

pub trait MemDev {
    fn load8(&self, addr: u64) -> u8;
    fn load16(&self, addr: u64) -> u16;
    fn load32(&self, addr: u64) -> u32;
    fn load64(&self, addr: u64) -> u64;

    fn store8(&self, addr: u64, val: u8);
    fn store16(&self, addr: u64, val: u16);
    fn store32(&self, addr: u64, val: u32);
    fn store64(&self, addr: u64, val: u64);
}

pub struct DevMapping {
    /// Inclusive.
    pub start: u64,
    /// Exclusive.
    pub size: u64,
    pub dev: Box<dyn MemDev>,
}

pub struct MemRegion {
    pub start: u64,
    pub size: u64,
    pub data: Box<[u8]>,
}

pub struct Bus {
    mem_regions: Vec<MemRegion>,
    mmio_devices: Vec<DevMapping>,
}

impl Bus {
    fn load_bytes<const N: usize>(&self, addr: u64) -> Result<[u8; N], Exception> {
        if let Some(reg) = self.find_mem_region(addr) {
            let i = (addr - reg.start) as usize;

            return reg.data[i..i + N].try_into().map_err(|_| Exception::LoadAccessFault);
        };

        // TODO: DevMappings

        Err(Exception::LoadAccessFault)
    }

    fn store_bytes<const N: usize>(&mut self, addr: u64, bytes: [u8; N]) -> Result<(), Exception> {
        if let Some(reg) = self.find_mem_region_mut(addr) {
            let i = (addr - reg.start) as usize;

            reg.data[i..i + N].copy_from_slice(&bytes);
            return Ok(());
        };

        // TODO: DevMappings

        Err(Exception::StoreAccessFault)
    }

    pub fn load8(&self, addr: u64) -> Result<u8, Exception> {
        Ok(self.load_bytes::<1>(addr)?[0])
    }

    pub fn load16(&self, addr: u64) -> Result<u16, Exception> {
        Ok(u16::from_le_bytes(self.load_bytes::<2>(addr)?))
    }

    pub fn load32(&self, addr: u64) -> Result<u32, Exception> {
        Ok(u32::from_le_bytes(self.load_bytes::<4>(addr)?))
    }

    pub fn load64(&self, addr: u64) -> Result<u64, Exception> {
        Ok(u64::from_le_bytes(self.load_bytes::<8>(addr)?))
    }

    pub fn store8(&mut self, addr: u64, val: u8) -> Result<(), Exception> {
        self.store_bytes::<1>(addr, [val])
    }

    pub fn store16(&mut self, addr: u64, val: u16) -> Result<(), Exception> {
        self.store_bytes::<2>(addr, val.to_le_bytes())
    }

    pub fn store32(&mut self, addr: u64, val: u32) -> Result<(), Exception> {
        self.store_bytes::<4>(addr, val.to_le_bytes())
    }

    pub fn store64(&mut self, addr: u64, val: u64) -> Result<(), Exception> {
        self.store_bytes::<8>(addr, val.to_le_bytes())
    }

    fn find_mem_region_index(&self, addr: u64) -> Option<usize> {
        self.mem_regions
            .binary_search_by(|reg| {
                if addr < reg.start {
                    std::cmp::Ordering::Greater
                } else if addr >= reg.start + reg.size {
                    std::cmp::Ordering::Less
                } else {
                    std::cmp::Ordering::Equal
                }
            })
            .ok()
    }

    fn find_mem_region(&self, addr: u64) -> Option<&MemRegion> {
        let i = self.find_mem_region_index(addr)?;
        Some(&self.mem_regions[i])
    }

    fn find_mem_region_mut(&mut self, addr: u64) -> Option<&mut MemRegion> {
        let i = self.find_mem_region_index(addr)?;
        Some(&mut self.mem_regions[i])
    }
}
