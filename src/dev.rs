use crate::exception::Exception;

pub mod ram;

pub trait MmioDev {
    fn load(&mut self, addr: u64, size: usize) -> u64;
    fn store(&mut self, addr: u64, size: usize, val: u64);
}

pub enum MemRegionKind {
    Ram(Box<[u8]>),
    Mmio(Box<dyn MmioDev>),
}

pub struct MemRegion {
    pub start: u64,
    pub size: u64,
    pub kind: MemRegionKind,
}

impl MemRegion {
    pub fn new_ram(start: u64, size: u64) -> Self {
        let data = vec![0u8; size as usize].into_boxed_slice();

        Self {
            start,
            size,
            kind: MemRegionKind::Ram(data),
        }
    }
}

pub struct Bus {
    pub regions: Vec<MemRegion>,
}

// TODO: So this whole thing should probably be rewritten with some sort of a fast path for RAM and
// just be faster bruh. A cache would also be nice here.
impl Bus {
    fn load_bytes<const N: usize>(&mut self, addr: u64) -> Result<u64, Exception> {
        if let Some(reg) = self.find_mem_region(addr) {
            let i = (addr - reg.start) as usize;

            match &mut reg.kind {
                MemRegionKind::Ram(data) => {
                    let mut buf = [0u8; 8];
                    buf[..N].copy_from_slice(&data[i..i + N]);
                    Ok(u64::from_le_bytes(buf))
                }
                MemRegionKind::Mmio(dev) => Ok(dev.load(i as u64, N)),
            }
        } else {
            Err(Exception::LoadAccessFault)
        }
    }

    fn store_bytes<const N: usize>(&mut self, addr: u64, val: u64) -> Result<(), Exception> {
        if let Some(reg) = self.find_mem_region(addr) {
            let i = (addr - reg.start) as usize;

            match &mut reg.kind {
                MemRegionKind::Ram(data) => data[i..i + N].copy_from_slice(&u64::to_le_bytes(val)[..N]),
                MemRegionKind::Mmio(dev) => dev.store(i as u64, N, val),
            }

            return Ok(());
        };

        Err(Exception::StoreAmoAccessFault)
    }

    pub fn load8(&mut self, addr: u64) -> Result<u8, Exception> {
        Ok(self.load_bytes::<1>(addr)? as u8)
    }

    pub fn load16(&mut self, addr: u64) -> Result<u16, Exception> {
        Ok(self.load_bytes::<2>(addr)? as u16)
    }

    pub fn load32(&mut self, addr: u64) -> Result<u32, Exception> {
        Ok(self.load_bytes::<4>(addr)? as u32)
    }

    pub fn load64(&mut self, addr: u64) -> Result<u64, Exception> {
        Ok(self.load_bytes::<8>(addr)? as u64)
    }

    pub fn store8(&mut self, addr: u64, val: u8) -> Result<(), Exception> {
        self.store_bytes::<1>(addr, val as u64)
    }

    pub fn store16(&mut self, addr: u64, val: u16) -> Result<(), Exception> {
        self.store_bytes::<2>(addr, val as u64)
    }

    pub fn store32(&mut self, addr: u64, val: u32) -> Result<(), Exception> {
        self.store_bytes::<4>(addr, val as u64)
    }

    pub fn store64(&mut self, addr: u64, val: u64) -> Result<(), Exception> {
        self.store_bytes::<8>(addr, val as u64)
    }

    fn find_mem_region(&mut self, addr: u64) -> Option<&mut MemRegion> {
        let i = self
            .regions
            .binary_search_by(|reg| {
                if addr < reg.start {
                    std::cmp::Ordering::Greater
                } else if addr >= reg.start + reg.size {
                    std::cmp::Ordering::Less
                } else {
                    std::cmp::Ordering::Equal
                }
            })
            .ok()?;

        Some(&mut self.regions[i])
    }
}
