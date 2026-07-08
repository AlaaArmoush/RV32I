# RV32I Processor

A single-cycle SystemVerilog implementation of the RISC-V 32-bit Integer (RV32I) instruction set architecture. 

## Structure

- **`src/`**: SystemVerilog modules for the CPU datapath and control.
  - `cpu.sv`: Top-level integration.
  - `alu.sv`: Arithmetic Logic Unit.
  - `control.sv`: Main control unit.
  - `regfile.sv`: 32-entry register file.
  - `memory.sv`: Combined instruction and data memory.
  - `signextnd.sv`: Immediate sign-extension logic.
  - `load_decoder.sv` / `store_decoder.sv`: Memory alignment decoders.
- **`tb/`**: Verilator testbenches for all components.
- **`tests/`**: Assembly test cases and compiled machine code.

## Prerequisites

To build, simulate, and compile custom assembly for this project, you will need the following tools installed:

1. **Verilator & Make** (Required for compiling and simulating the SystemVerilog CPU)
2. **RISC-V GNU Compiler Toolchain** (Required ONLY if you want to compile custom assembly programs)

**Debian/Ubuntu:**
```bash
sudo apt install verilator make gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
```

**Fedora/RHEL:**
```bash
sudo dnf install verilator make gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu
```

## 1. Running Built-In Tests

The project includes built-in Verilator testbenches to verify the CPU and its individual components against the standard test suite.

To test a specific module (e.g., the ALU):
```bash
make build-alu
make run-alu
```
*(You can replace `alu` with `control`, `regfile`, `memory`, etc.)*

To compile and test the fully integrated CPU:
```bash
make build-for-cpu
make run-for-cpu
```

## 2. Writing & Compiling Custom Assembly

If you want to write your own assembly programs (`.s`) and run them on the CPU, you can use the built-in assembler helper to automatically convert them to the `.hex` format. This relies on the standard `riscv64-linux-gnu-gcc` cross-compiler.

To compile a program, write your `.s` file (ensuring it starts with the `.global _start` directive and the `_start:` label), and run:
```bash
make assemble SOURCE=custom_prog.s OUT=custom_prog.hex
```

## 3. Running Custom Programs on the CPU

Once your program is compiled into a hexadecimal file, you can load and run it on the CPU dynamically without modifying the testbenches. 

Use the `ARGS` variable when running the top-level testbench:
```bash
make run-for-cpu ARGS="+imem=./custom_prog.hex"
```

---

*The architecture and design are directly based on the processor model detailed in **Chapter 7** of ["Digital Design and Computer Architecture: RISC-V Edition"](https://drive.google.com/file/d/14ybBzopLFuVmjYHVECjl4Is-Sj7eNcAj/view?usp=drive_link) by Sarah Harris and David Harris.*
