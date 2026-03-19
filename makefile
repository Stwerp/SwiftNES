# =============================================================================
# iCEbreaker build — usb_hid_host
# Toolchain: Yosys + nextpnr-ice40 + IceStorm (OSS CAD Suite)
# Usage:
#   make                              — synthesise, place, route, pack
#   make prog                         — flash to iCEbreaker
#   make V=1                          — verbose build output
#   make clean                        — remove build artefacts
#   make utilisation                  — print resource and timing summary
#
# Toolchain path:
#   OSS_CAD_SUITE_PATH defaults to ~/oss-cad-suite
#   Override at the command line:
#     OSS_CAD_SUITE_PATH=/path/to/oss-cad-suite make
#   Or export in your shell rc:
#     export OSS_CAD_SUITE_PATH=/path/to/oss-cad-suite
# =============================================================================

TOP     := top
DEVICE  := up5k
PACKAGE := sg48
PCF     := icebreaker.pcf

SOURCES := \
	rtl/pll.v \
	rtl/usb_io.v \
	rtl/usb_hid_host_rom.v \
	rtl/usb_hid_host.v \
	rtl/top.v

# -----------------------------------------------------------------------------
# OSS CAD Suite environment
# -----------------------------------------------------------------------------
OSS_CAD_SUITE_PATH ?= $(HOME)/oss-cad-suite

export PATH := $(OSS_CAD_SUITE_PATH)/bin:$(PATH)

$(OSS_CAD_SUITE_PATH)/bin/yosys:
	$(error OSS CAD Suite not found at $(OSS_CAD_SUITE_PATH). \
	Set OSS_CAD_SUITE_PATH to your install location)

# -----------------------------------------------------------------------------
# Verbosity — make V=1 for full toolchain output
# -----------------------------------------------------------------------------
ifeq ($(V),1)
  YOSYS_FLAGS :=
  PNR_FLAGS   :=
  QUIET       :=
else
  YOSYS_FLAGS := -q
  PNR_FLAGS   := -q
  QUIET       := @
endif

# -----------------------------------------------------------------------------
# Build targets
# -----------------------------------------------------------------------------
.PHONY: all
all: $(TOP).bin

# Synthesis: Verilog -> JSON netlist
$(TOP).json: $(SOURCES)
	@echo "  SYN   $@"
	$(QUIET)yosys $(YOSYS_FLAGS) \
		-p "synth_ice40 -top $(TOP) -json $@" \
		$(SOURCES)

# Place and route: JSON + PCF -> ASC
$(TOP).asc: $(TOP).json $(PCF)
	@echo "  PNR   $@"
	$(QUIET)nextpnr-ice40 $(PNR_FLAGS) \
		--$(DEVICE) \
		--package $(PACKAGE) \
		--json $< \
		--pcf $(PCF) \
		--asc $@

# Bitstream packing: ASC -> BIN
$(TOP).bin: $(TOP).asc
	@echo "  PACK  $@"
	$(QUIET)icepack $< $@

# -----------------------------------------------------------------------------
# Utility targets
# -----------------------------------------------------------------------------

# Flash to iCEbreaker
.PHONY: prog
prog: $(TOP).bin
	@echo "  PROG  $<"
	$(QUIET)iceprog $

# Print resource and timing summary
.PHONY: utilisation
utilisation: $(TOP).asc
	@echo "  UTIL"
	$(QUIET)nextpnr-ice40 \
		--$(DEVICE) \
		--package $(PACKAGE) \
		--json $(TOP).json \
		--pcf $(PCF) \
		--asc /dev/null \
		--report /dev/stdout 2>&1 | grep -E "ICESTORM|SB_IO|SB_PLL|Timing"

# Remove build artifacts
.PHONY: clean
clean:
	@echo "  CLEAN"
	$(QUIET)rm -f $(TOP).json $(TOP).asc $(TOP).bin