# Makefile: run original command, then move obj_dir into build/<tbname>/obj_dir

BUILD_DIR = build
SRC_DIR   = src
TB_DIR    = tb

# Automatically find all testbenches ending with _tb.sv
TBS = $(notdir $(basename $(wildcard $(TB_DIR)/*_tb.sv)))

# Build rule: run original command, then move obj_dir
build-%: $(SRC_DIR)/%.sv $(TB_DIR)/%_tb.sv
		verilator --binary $(SRC_DIR)/$*.sv $(TB_DIR)/$*_tb.sv --top $*_tb -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND
	mkdir -p $(BUILD_DIR)/$*       # create per-testbench folder if needed
	mv obj_dir $(BUILD_DIR)/$*/obj_dir

# Run a testbench: binary is inside obj_dir
run-%:
	./$(BUILD_DIR)/$*/obj_dir/V$*_tb $(ARGS)
	

# ---- Special build for CPU (needs all src/*.sv modules) ----
build-for-cpu:
	mkdir -p $(BUILD_DIR)/cpu/obj_dir
	verilator --binary $(wildcard $(SRC_DIR)/*.sv) $(TB_DIR)/cpu_tb.sv --top cpu_tb \
		--Mdir $(BUILD_DIR)/cpu/obj_dir -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND

run-for-cpu:
	./$(BUILD_DIR)/cpu/obj_dir/Vcpu_tb $(ARGS)


# Build all testbenches
all: $(TBS:%=build-%)

clean-%:
	rm -rf $(BUILD_DIR)/$*

# Clean all build outputs
clean:
	rm -rf $(BUILD_DIR)/*
	rm -f *.hex *.elf *.bin

.PHONY: all clean run-% build-% assemble

# ---- Assembler Helper ----
# Compile RISC-V assembly (.s) to hex memory file (.hex)
assemble:
	@if [ -z "$(SOURCE)" ] || [ -z "$(OUT)" ]; then \
		echo "Usage: make assemble SOURCE=program.s OUT=program.hex"; \
		exit 1; \
	fi
	riscv64-linux-gnu-gcc -march=rv32i -mabi=ilp32 -Wl,-Ttext=0x0 -nostdlib $(SOURCE) -o $(OUT).elf
	riscv64-linux-gnu-objcopy -O binary -j .text $(OUT).elf $(OUT).bin
	hexdump -v -e '1/4 "%08x\n"' $(OUT).bin > $(OUT)
	rm -f $(OUT).elf $(OUT).bin
	@echo "Successfully compiled $(SOURCE) to $(OUT)!"
