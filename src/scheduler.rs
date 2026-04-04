use std::cmp::Reverse;
use std::collections::BinaryHeap;

use crate::dev::{Bus, DevActions};

#[derive(Debug, PartialEq, Eq)]
pub struct Schedulable {
    pub cycle: u64,
    // TODO: This is unsafe and should ideally be replaced with something like a unique ID in the future
    pub index: usize,
}

impl PartialOrd for Schedulable {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        self.cycle.partial_cmp(&other.cycle)
    }
}

impl Ord for Schedulable {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.cycle.cmp(&other.cycle)
    }
}

pub struct Scheduler {
    schedulables: BinaryHeap<Reverse<Schedulable>>,
    next_deadline: u64,
}

impl Scheduler {
    pub fn new() -> Self {
        Scheduler {
            schedulables: BinaryHeap::new(),
            next_deadline: u64::max_value(),
        }
    }

    pub fn next_deadline(&self) -> u64 {
        self.next_deadline
    }

    pub fn schedule_at(&mut self, cycle: u64, index: usize) {
        println!("New event scheduled for cycle {}", cycle);

        self.schedulables.push(Reverse(Schedulable { cycle, index }));

        if cycle < self.next_deadline {
            println!("Shortening the next deadline");
            self.next_deadline = cycle;
        }
    }

    pub fn service_due(&mut self, bus: &mut Bus, cur_cycle: u64) {
        while let Some(Reverse(e)) = self.schedulables.peek() {
            if e.cycle > cur_cycle {
                break;
            }

            let Reverse(sched) = self.schedulables.pop().unwrap();

            let mut actions = DevActions {
                cycles_now: cur_cycle,
                requests: Vec::with_capacity(2),
            };

            match &mut bus.regions[sched.index].kind {
                crate::dev::MemRegionKind::Ram(_) => panic!(),
                crate::dev::MemRegionKind::Mmio(dev) => {
                    dev.on_service(&mut actions).unwrap();
                }
            }

            for req in actions.requests {
                self.schedulables.push(Reverse(Schedulable {
                    index: sched.index,
                    cycle: req.cycle,
                }));
            }

            // TODO: Service the device
            println!("  device serviced");
        }

        self.next_deadline = self.schedulables.peek().map(|Reverse(e)| e.cycle).unwrap_or(u64::max_value());
        println!("  No devices left to service");
    }
}
