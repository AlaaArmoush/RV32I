.global _start

_start:
    # --- 1. Basic ALU & Immediates ---
    addi x1, x0, 10          # x1 = 10
    addi x2, x0, -5          # x2 = -5 (0xFFFFFFFB)
    add  x3, x1, x2          # x3 = 10 + (-5) = 5
    sub  x4, x1, x3          # x4 = 10 - 5 = 5
    and  x5, x1, x3          # x5 = 10 & 5 (1010 & 0101) = 0
    or   x6, x1, x3          # x6 = 10 | 5 (1010 | 0101) = 15 (0xF)
    xor  x7, x1, x6          # x7 = 10 ^ 15 = 5

    # --- 2. Upper Immediates ---
    lui x8, 0x12345          # x8 = 0x12345000
    auipc x9, 0              # x9 = current PC (approx 0x1c)

    # --- 3. Memory: Words ---
    sw x8, 12(x0)            # Store 0x12345000 at address 12
    lw x10, 12(x0)           # Load it back: x10 = 0x12345000

    # --- 4. Memory: Bytes / Halfwords ---
    addi x11, x0, 0xAB       # x11 = 0x000000AB
    sb x11, 16(x0)           # Store byte 0xAB at address 16
    lb x12, 16(x0)           # Load byte, sign-extended: x12 = 0xFFFFFFAB
    lbu x13, 16(x0)          # Load byte, zero-extended: x13 = 0x000000AB

    # --- 5. Branching (Skipping traps) ---
    beq x1, x1, branch_eq    # 10 == 10, taken!
    addi x14, x0, 999      # Trap 1

branch_eq:
    bne x1, x2, branch_ne    # 10 != -5, taken!
    addi x14, x0, 999      # Trap 2

branch_ne:
    blt x2, x1, branch_lt    # -5 < 10, taken!
    addi x14, x0, 999      # Trap 3

branch_lt:
    # --- 6. Jumps ---
    jal x15, jump_target     # Jump forward, link in x15
    addi x14, x0, 999      # Trap 4

jump_target:
    auipc x16, 0             # Get current PC into x16
    addi x16, x16, 16        # Offset to jalr_target
    jalr x17, 0(x16)         # Jump to x16 + 0, link in x17

    addi x14, x0, 999      # Trap 5

jalr_target:
    # --- 7. Success State ---
    addi x31, x0, 0x777      # Success flag in x31!

halt:
    beq x0, x0, halt         # Infinite loop to gracefully halt CPU
