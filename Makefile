# Compiler and simulation tools
IVERILOG = iverilog
VVP = vvp

# Directories
SRC_DIR = src
TEST_DIR = test
BUILD_DIR = build

# File lists
SRC_FILES = $(wildcard $(SRC_DIR)/*.v)
TEST_BENCHES = $(wildcard $(TEST_DIR)/*.v)

# Derived object and output names
SIM_EXES = $(patsubst $(TEST_DIR)/%.v, $(BUILD_DIR)/%.out, $(TEST_BENCHES))
VCD_FILES = $(patsubst $(TEST_DIR)/%.v, $(BUILD_DIR)/%.vcd, $(TEST_BENCHES))

# Default target
all: $(BUILD_DIR) $(VCD_FILES)

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile and simulate each testbench
$(BUILD_DIR)/%.vcd: $(TEST_DIR)/%.v $(SRC_FILES) | $(BUILD_DIR)
	@echo "Compiling and running testbench: $<"
	$(IVERILOG) -o $(BUILD_DIR)/$*.out $(SRC_FILES) $<
	$(VVP) $(BUILD_DIR)/$*.out

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Phony targets
.PHONY: all clean
