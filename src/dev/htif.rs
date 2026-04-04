use crate::dev::MmioDev;

pub struct Htif {
    to_host: u64,
    a: bool,
}

impl Htif {
    pub fn new() -> Self {
        Htif { to_host: 0, a: false }
    }
}

impl MmioDev for Htif {
    fn load(&mut self, actions: &mut super::DevActions, addr: u64, size: usize) -> Result<u64, crate::exception::Exception> {
        if addr > 0 {
            return Ok(0);
        }

        if !self.a {
            println!("HTIF scheduled");
            actions.schedule_in(50);
            self.a = true;
        }

        println!("HTIF load{}: {}", size, self.to_host);
        Ok(self.to_host)
    }

    fn store(&mut self, actions: &mut super::DevActions, addr: u64, size: usize, val: u64) -> Result<(), crate::exception::Exception> {
        if addr > 0 {
            return Ok(());
        }

        if !self.a {
            println!("HTIF scheduled");
            actions.schedule_in(50);
            self.a = true;
        }

        println!("HTIF store{}: {}", size, val);
        self.to_host = val;

        Ok(())
    }
}
