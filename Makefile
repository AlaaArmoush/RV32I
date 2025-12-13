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
	./$(BUILD_DIR)/$*/obj_dir/V$*_tb	
	

# ---- Special build for CPU (needs all src/*.sv modules) ----
build-for-cpu:
	verilator --binary $(wildcard $(SRC_DIR)/*.sv) $(TB_DIR)/cpu_tb.sv --top cpu_tb \
		--Mdir $(BUILD_DIR)/cpu/obj_dir -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND

run-for-cpu:
	./$(BUILD_DIR)/cpu/obj_dir/Vcpu_tb


# Build all testbenches
all: $(TBS:%=build-%)

clean-%:
	rm -rf $(BUILD_DIR)/$*

# Clean all build outputs
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: all clean run-% build-%

