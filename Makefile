# Makefile for SwiftNES - USB/PS2 Keyboard to NES Controller
# Requires open-source FPGA toolchain: yosys, nextpnr-ice40, icepack

PROJECT = swiftnes
DEVICE = up5k
PACKAGE = sg48

# Default: USB version
TOP_MODULE ?= top
VERILOG_SRC ?= rtl/top.v \
               rtl/usb_hid_host.v \
               rtl/keyboard_to_nes.v \
               rtl/nes_controller_interface.v

# Constraint file
PCF = constraints/icebreaker.pcf

# Build directory
BUILD_DIR = build

# Tools
YOSYS = yosys
NEXTPNR = nextpnr-ice40
ICEPACK = icepack
ICEPROG = iceprog
ICETIME = icetime

.PHONY: all ps2 clean prog timing help

# Default target: USB version
all: $(BUILD_DIR)/$(PROJECT).bin

# PS/2 version
ps2:
	$(MAKE) all TOP_MODULE=top_ps2 \
		VERILOG_SRC="rtl/top_ps2.v rtl/ps2_keyboard_host.v rtl/ps2_to_nes.v rtl/nes_controller_interface.v" \
		PROJECT=swiftnes_ps2

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Synthesis
$(BUILD_DIR)/$(PROJECT).json: $(VERILOG_SRC) | $(BUILD_DIR)
	$(YOSYS) -p "synth_ice40 -top $(TOP_MODULE) -json $@" $(VERILOG_SRC)

# Place and Route
$(BUILD_DIR)/$(PROJECT).asc: $(BUILD_DIR)/$(PROJECT).json $(PCF)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

# Generate bitstream
$(BUILD_DIR)/$(PROJECT).bin: $(BUILD_DIR)/$(PROJECT).asc
	$(ICEPACK) $< $@

# Program FPGA
prog: $(BUILD_DIR)/$(PROJECT).bin
	$(ICEPROG) $<

# Timing analysis
timing: $(BUILD_DIR)/$(PROJECT).asc
	$(ICETIME) -d $(DEVICE) -mtr $(BUILD_DIR)/$(PROJECT).rpt $<

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Help
help:
	@echo "SwiftNES Build System"
	@echo "====================="
	@echo "Targets:"
	@echo "  all     - Build USB version bitstream (default)"
	@echo "  ps2     - Build PS/2 version bitstream (recommended)"
	@echo "  prog    - Program iCEBreaker board"
	@echo "  timing  - Run timing analysis"
	@echo "  clean   - Remove build artifacts"
	@echo ""
	@echo "Note: PS/2 version is recommended as it has a complete"
	@echo "      implementation. USB version requires additional work."
	@echo ""
	@echo "Requirements:"
	@echo "  - yosys (synthesis)"
	@echo "  - nextpnr-ice40 (place and route)"
	@echo "  - icepack (bitstream generation)"
	@echo "  - iceprog (programming tool)"
