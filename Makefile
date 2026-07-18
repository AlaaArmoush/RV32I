# =============================================================================
# Directories
# =============================================================================
BUILD_DIR = build
SRC_DIR   = src
TB_DIR    = tb

# =============================================================================
# Verilator configuration
# =============================================================================
VERILATOR       ?= verilator
VERILATOR_FLAGS := -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND
COVERAGE_FLAGS  := --coverage

# =============================================================================
# Testbench file lists
# Each per-block list is ordered: package -> classes -> modules -> top harness.
# =============================================================================

ALU_TB_FILES = \
	$(TB_DIR)/alu/alu_pkg.sv \
	$(TB_DIR)/alu/alu_item.sv \
	$(TB_DIR)/alu/alu_generator.sv \
	$(TB_DIR)/alu/alu_scoreboard.sv \
	$(TB_DIR)/alu/alu_coverage.sv \
	$(TB_DIR)/alu/alu_sva.sv \
	$(TB_DIR)/alu/alu_tb.sv

REGFILE_TB_FILES = \
	$(TB_DIR)/regfile/regfile_if.sv \
	$(TB_DIR)/regfile/regfile_item.sv \
	$(TB_DIR)/regfile/regfile_driver.sv \
	$(TB_DIR)/regfile/regfile_monitor.sv \
	$(TB_DIR)/regfile/regfile_scoreboard.sv \
	$(TB_DIR)/regfile/regfile_coverage.sv \
	$(TB_DIR)/regfile/regfile_sva.sv \
	$(TB_DIR)/regfile/regfile_tb.sv

MEMORY_TB_FILES = \
	$(TB_DIR)/memory/memory_if.sv \
	$(TB_DIR)/memory/memory_item.sv \
	$(TB_DIR)/memory/memory_sequence.sv \
	$(TB_DIR)/memory/memory_driver.sv \
	$(TB_DIR)/memory/memory_monitor.sv \
	$(TB_DIR)/memory/memory_scoreboard.sv \
	$(TB_DIR)/memory/memory_coverage.sv \
	$(TB_DIR)/memory/memory_sva.sv \
	$(TB_DIR)/memory/memory_tb.sv

# =============================================================================
# Per-block explicit build targets
# Explicit targets take precedence over the generic build-% pattern below.
# =============================================================================

# ---- ALU ----
build-alu: $(SRC_DIR)/alu.sv $(ALU_TB_FILES)
	mkdir -p $(BUILD_DIR)/alu/obj_dir
	$(VERILATOR) --binary --assert \
		$(SRC_DIR)/alu.sv $(ALU_TB_FILES) \
		--top alu_tb --Mdir $(BUILD_DIR)/alu/obj_dir $(VERILATOR_FLAGS)

build-alu-cov: $(SRC_DIR)/alu.sv $(ALU_TB_FILES)
	mkdir -p $(BUILD_DIR)/alu/obj_dir_cov
	$(VERILATOR) --binary --assert $(COVERAGE_FLAGS) \
		$(SRC_DIR)/alu.sv $(ALU_TB_FILES) \
		--top alu_tb --Mdir $(BUILD_DIR)/alu/obj_dir_cov $(VERILATOR_FLAGS)

# ---- Regfile ----
build-regfile: $(SRC_DIR)/regfile.sv $(REGFILE_TB_FILES)
	mkdir -p $(BUILD_DIR)/regfile/obj_dir
	$(VERILATOR) --binary \
		$(SRC_DIR)/regfile.sv $(REGFILE_TB_FILES) \
		--top regfile_tb --Mdir $(BUILD_DIR)/regfile/obj_dir $(VERILATOR_FLAGS)

build-regfile-cov: $(SRC_DIR)/regfile.sv $(REGFILE_TB_FILES)
	mkdir -p $(BUILD_DIR)/regfile/obj_dir_cov
	$(VERILATOR) --binary $(COVERAGE_FLAGS) \
		$(SRC_DIR)/regfile.sv $(REGFILE_TB_FILES) \
		--top regfile_tb --Mdir $(BUILD_DIR)/regfile/obj_dir_cov $(VERILATOR_FLAGS)

# ---- Memory ----
build-memory: $(SRC_DIR)/memory.sv $(MEMORY_TB_FILES)
	mkdir -p $(BUILD_DIR)/memory/obj_dir
	$(VERILATOR) --binary \
		$(SRC_DIR)/memory.sv $(MEMORY_TB_FILES) \
		--top memory_tb --Mdir $(BUILD_DIR)/memory/obj_dir $(VERILATOR_FLAGS)

build-memory-cov: $(SRC_DIR)/memory.sv $(MEMORY_TB_FILES)
	mkdir -p $(BUILD_DIR)/memory/obj_dir_cov
	$(VERILATOR) --binary $(COVERAGE_FLAGS) \
		$(SRC_DIR)/memory.sv $(MEMORY_TB_FILES) \
		--top memory_tb --Mdir $(BUILD_DIR)/memory/obj_dir_cov $(VERILATOR_FLAGS)


# =============================================================================

build-%: $(SRC_DIR)/%.sv $(TB_DIR)/%_tb.sv
	mkdir -p $(BUILD_DIR)/$*/obj_dir
	$(VERILATOR) --binary \
		$(SRC_DIR)/$*.sv $(TB_DIR)/$*_tb.sv \
		--top $*_tb --Mdir $(BUILD_DIR)/$*/obj_dir $(VERILATOR_FLAGS)

build-%-cov: $(SRC_DIR)/%.sv $(TB_DIR)/%_tb.sv
	mkdir -p $(BUILD_DIR)/$*/obj_dir_cov
	$(VERILATOR) --binary $(COVERAGE_FLAGS) \
		$(SRC_DIR)/$*.sv $(TB_DIR)/$*_tb.sv \
		--top $*_tb --Mdir $(BUILD_DIR)/$*/obj_dir_cov $(VERILATOR_FLAGS)

# =============================================================================
# Run and coverage report pattern rules
# =============================================================================

run-%: build-%
	./$(BUILD_DIR)/$*/obj_dir/V$*_tb $(ARGS)

run-%-cov: build-%-cov
	./$(BUILD_DIR)/$*/obj_dir_cov/V$*_tb \
		+verilator+coverage+file+$(BUILD_DIR)/$*/coverage.dat $(ARGS)

report-%-cov:
	verilator_coverage --report summary,hier $(BUILD_DIR)/$*/coverage.dat

# =============================================================================
# CPU integrated environment (needs all RTL modules)
# =============================================================================

build-for-cpu:
	mkdir -p $(BUILD_DIR)/cpu/obj_dir
	$(VERILATOR) --binary \
		$(wildcard $(SRC_DIR)/*.sv) $(TB_DIR)/cpu_tb.sv \
		--top cpu_tb --Mdir $(BUILD_DIR)/cpu/obj_dir $(VERILATOR_FLAGS)

run-for-cpu:
	./$(BUILD_DIR)/cpu/obj_dir/Vcpu_tb $(ARGS)

# =============================================================================
# Aggregate and clean targets
# =============================================================================

# Automatically discover all testbench blocks (flat and per-block directories).
FLAT_TBS  = $(patsubst $(TB_DIR)/%_tb.sv,%,$(wildcard $(TB_DIR)/*_tb.sv))
SPLIT_TBS = $(patsubst $(TB_DIR)/%/,%,$(sort $(dir $(wildcard $(TB_DIR)/*/*_tb.sv))))
TBS       = $(sort $(FLAT_TBS) $(SPLIT_TBS))
LEAF_TBS  = $(filter-out cpu,$(TBS))

# Build all leaf testbenches (CPU uses build-for-cpu separately).
all: $(LEAF_TBS:%=build-%)

clean-%:
	rm -rf $(BUILD_DIR)/$*

clean:
	rm -rf $(BUILD_DIR)/*
	rm -f *.hex *.elf *.bin

# =============================================================================
# Assembler helper
# Usage: make assemble SOURCE=program.s OUT=program.hex
# =============================================================================

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

.PHONY: all clean clean-% \
        build-% build-%-cov run-% run-%-cov report-%-cov \
        build-alu build-alu-cov \
        build-regfile build-regfile-cov \
        build-memory build-memory-cov \
        build-for-cpu run-for-cpu \
        assemble
