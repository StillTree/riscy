trait MemDev {
    fn load8(&self, addr: u64) -> u8;
    fn load16(&self, addr: u64) -> u16;
    fn load32(&self, addr: u64) -> u32;
    fn load64(&self, addr: u64) -> u64;

    fn store8(&self, addr: u64, val: u8);
    fn store16(&self, addr: u64, val: u16);
    fn store32(&self, addr: u64, val: u32);
    fn store64(&self, addr: u64, val: u64);
}
