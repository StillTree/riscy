pub const Opcode = enum(u7) {
    imm = 0b0010011,
};

pub const ImmFunct3 = enum(u3) {
    addi = 0b000,
};
