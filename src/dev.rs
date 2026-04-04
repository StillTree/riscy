use crate::{exception::Exception, scheduler::Scheduler};

pub mod htif;

pub struct Req {
    pub cycle: u64,
}

pub struct DevActions {
    pub cycles_now: u64,
    pub requests: Vec<Req>,
}

impl DevActions {
    pub fn cycles_now(&self) -> u64 {
        self.cycles_now
    }

    pub fn schedule_in(&mut self, cycles: u64) {
        self.requests.push(Req {
            cycle: self.cycles_now.saturating_add(cycles),
        });
    }

    pub fn schedule_at(&mut self, cycle: u64) {
        self.requests.push(Req { cycle });
    }
}

pub trait MmioDev {
    fn load(&mut self, actions: &mut DevActions, addr: u64, size: usize) -> Result<u64, Exception>;
    fn store(&mut self, actions: &mut DevActions, addr: u64, size: usize, val: u64) -> Result<(), Exception>;

    #[allow(unused)]
    fn on_service(&mut self, actions: &mut DevActions) -> Result<(), Exception> {
        Ok(())
    }
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

    pub fn new_mmio(start: u64, size: u64, dev: Box<dyn MmioDev>) -> Self {
        Self {
            start,
            size,
            kind: MemRegionKind::Mmio(dev),
        }
    }
}

pub struct Bus {
    pub regions: Vec<MemRegion>,
}

// TODO: So this whole thing should probably be rewritten with some sort of a fast path for RAM and
// just be faster bruh. A cache would also be nice here.
impl Bus {
    fn load_bytes<const N: usize>(&mut self, addr: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<u64, Exception> {
        if let Some((reg, index)) = self.find_mem_region(addr) {
            let i = (addr - reg.start) as usize;

            match &mut reg.kind {
                MemRegionKind::Ram(data) => {
                    let mut buf = [0u8; 8];
                    buf[..N].copy_from_slice(&data[i..i + N]);
                    Ok(u64::from_le_bytes(buf))
                }
                MemRegionKind::Mmio(dev) => {
                    let mut actions = DevActions {
                        cycles_now,
                        // TODO: Use array instead of vec
                        requests: Vec::with_capacity(2),
                    };

                    let val = dev.load(&mut actions, i as u64, N)?;

                    for req in actions.requests {
                        sched.schedule_at(req.cycle, index);
                    }

                    Ok(val)
                }
            }
        } else {
            Err(Exception::LoadAccessFault)
        }
    }

    fn store_bytes<const N: usize>(&mut self, addr: u64, val: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<(), Exception> {
        if let Some((reg, index)) = self.find_mem_region(addr) {
            let i = (addr - reg.start) as usize;

            match &mut reg.kind {
                MemRegionKind::Ram(data) => {
                    data[i..i + N].copy_from_slice(&val.to_le_bytes()[..N]);

                    Ok(())
                }
                MemRegionKind::Mmio(dev) => {
                    let mut actions = DevActions {
                        cycles_now,
                        // TODO: Use array instead of vec
                        requests: Vec::with_capacity(2),
                    };

                    dev.store(&mut actions, i as u64, N, val)?;

                    for req in actions.requests {
                        sched.schedule_at(req.cycle, index);
                    }

                    Ok(())
                }
            }
        } else {
            Err(Exception::StoreAmoAccessFault)
        }
    }

    pub fn load8(&mut self, addr: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<u8, Exception> {
        Ok(self.load_bytes::<1>(addr, cycles_now, sched)? as u8)
    }

    pub fn load16(&mut self, addr: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<u16, Exception> {
        Ok(self.load_bytes::<2>(addr, cycles_now, sched)? as u16)
    }

    pub fn load32(&mut self, addr: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<u32, Exception> {
        Ok(self.load_bytes::<4>(addr, cycles_now, sched)? as u32)
    }

    pub fn load64(&mut self, addr: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<u64, Exception> {
        Ok(self.load_bytes::<8>(addr, cycles_now, sched)? as u64)
    }

    pub fn store8(&mut self, addr: u64, val: u8, cycles_now: u64, sched: &mut Scheduler) -> Result<(), Exception> {
        self.store_bytes::<1>(addr, val as u64, cycles_now, sched)
    }

    pub fn store16(&mut self, addr: u64, val: u16, cycles_now: u64, sched: &mut Scheduler) -> Result<(), Exception> {
        self.store_bytes::<2>(addr, val as u64, cycles_now, sched)
    }

    pub fn store32(&mut self, addr: u64, val: u32, cycles_now: u64, sched: &mut Scheduler) -> Result<(), Exception> {
        self.store_bytes::<4>(addr, val as u64, cycles_now, sched)
    }

    pub fn store64(&mut self, addr: u64, val: u64, cycles_now: u64, sched: &mut Scheduler) -> Result<(), Exception> {
        self.store_bytes::<8>(addr, val as u64, cycles_now, sched)
    }

    fn find_mem_region(&mut self, addr: u64) -> Option<(&mut MemRegion, usize)> {
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

        Some((&mut self.regions[i], i))
    }
}
