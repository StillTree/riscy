use std::cmp::Reverse;
use std::collections::BinaryHeap;

#[derive(Debug, PartialEq, Eq)]
pub struct Schedulable {
    pub cycle: u64,
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

    pub fn schedule_at(&mut self, cycle: u64) {
        println!("New event scheduled for cycle {}", cycle);

        self.schedulables.push(Reverse(Schedulable { cycle }));

        if cycle < self.next_deadline {
            println!("Shortening the next deadline");
            self.next_deadline = cycle;
        }
    }

    pub fn service_due(&mut self, cur_cycle: u64) {
        while let Some(e) = self.schedulables.peek() {
            if e.0.cycle > cur_cycle {
                break;
            }

            println!("  device serviced");
            self.schedulables.pop();
        }

        println!("  No devices left to service");
        self.next_deadline = if let Some(e) = self.schedulables.peek() {
            e.0.cycle
        } else {
            u64::max_value()
        };
    }
}
