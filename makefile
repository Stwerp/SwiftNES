# =============================================================================
# iCEbreaker build — usb_hid_host + UART/LED features
# Toolchain: Yosys + nextpnr-ice40 + IceStorm (OSS CAD Suite)
# Usage:
#   make                              — synthesise, place, route, pack
#   make prog                         — flash to iCEbreaker
#   make V=1                          — verbose build output
#   make clean                        — remove build artefacts
#   make utilisation                  — print resource and timing summary
#
# Features:
#   - USB HID host core
#   - UART keyboard event streaming (hid_uart_reporter)
#   - Heartbeat and USB status LEDs
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

# Tools (override at the command line if needed, e.g. `make YOSYS=/path/to/yosys`)
YOSYS   ?= yosys
NEXTPNR ?= nextpnr-ice40
ICEPACK ?= icepack
ICEPROG ?= iceprog

# Absolute path to the repository root (directory containing this makefile).
# This makes builds robust when invoking make from another working directory.
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SOURCES := \
	rtl/pll.v \
	rtl/usb_io.v \
	rtl/usb_hid_host_rom.v \
	rtl/usb_hid_host.v \
	rtl/hid_uart_reporter.v \
	rtl/uart_tx.v \
	rtl/top.v

ROM_INIT_SRC := rom/usb_hid_host_rom.mem

# Generated ROM init (always exactly 1024 nibbles). This avoids silent issues
# when the source .mem is shorter than the ROM depth.
BUILD_DIR := build
ROM_INIT  := $(BUILD_DIR)/usb_hid_host_rom.mem

# Define passed to Yosys so usb_hid_host_rom.v reads the generated init file.
ROM_MEM_DEFINE := -DUSB_HID_HOST_ROM_MEMFILE=\"$(ROM_INIT)\"

# Regenerate the source ROM .mem from the UKP assembly.
.PHONY: romgen
romgen:
	@echo "  ROMGEN"
	$(QUIET)python3 rom/asukp.py

$(ROM_INIT): $(ROM_INIT_SRC)
	@echo "  ROM   $@"
	$(QUIET)mkdir -p $(BUILD_DIR)
	$(QUIET)python3 - <<'PY'
import pathlib

src = pathlib.Path(r"$(ROM_INIT_SRC)")
dst = pathlib.Path(r"$(ROM_INIT)")

tokens = []
for raw in src.read_text(encoding="utf-8").splitlines():
	line = raw.strip()
	if not line or line.startswith("#") or line.startswith("//"):
		continue
	# allow whitespace-separated tokens per line
	for tok in line.split():
		try:
			val = int(tok, 16)
		except ValueError as e:
			raise SystemExit(f"Invalid hex token in {src}: {tok!r} (line: {raw!r})") from e
		if not (0 <= val <= 0xF):
			raise SystemExit(f"ROM token out of range (need 0..F) in {src}: {tok!r}")
		tokens.append(val)

DEPTH = 1024
if len(tokens) > DEPTH:
	raise SystemExit(f"ROM init has {len(tokens)} entries, exceeds {DEPTH}: {src}")
if len(tokens) < DEPTH:
	missing = DEPTH - len(tokens)
	print(f"WARN: ROM init short ({len(tokens)}/{DEPTH}); padding {missing} zeros", flush=True)
	tokens.extend([0] * missing)

dst.write_text("\n".join(format(v, "x") for v in tokens) + "\n", encoding="utf-8")
PY

# -----------------------------------------------------------------------------
# OSS CAD Suite environment
# -----------------------------------------------------------------------------
OSS_CAD_SUITE_PATH ?= $(HOME)/oss-cad-suite

# If OSS CAD Suite is present, prefer its binaries; otherwise rely on PATH.
ifneq ($(wildcard $(OSS_CAD_SUITE_PATH)/bin/yosys),)
	export PATH := $(OSS_CAD_SUITE_PATH)/bin:$(PATH)
endif

# Yosys provides iCE40 simulation cells under its data directory.
# Using +/ keeps this portable across OSS CAD Suite vs distro installs.
ICE40_CELLS_SIM := +/ice40/cells_sim.v

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

# -----------------------------------------------------------------------------
# Debug / validation targets
# -----------------------------------------------------------------------------

# Quickly list modules Yosys loaded; useful to confirm usb_hid_host_rom is read.
.PHONY: yosys-ls
yosys-ls: $(SOURCES) $(ROM_INIT)
	@echo "  YOSYS LS"
	$(QUIET)cd "$(ROOT)"; $(YOSYS) $(YOSYS_FLAGS) -l $(TOP).yosys.ls.log \
		-p "read_verilog -lib $(ICE40_CELLS_SIM)" \
		-p "read_verilog -sv rtl/pll.v" \
		-p "read_verilog -sv rtl/usb_io.v" \
		-p "read_verilog -sv $(ROM_MEM_DEFINE) rtl/usb_hid_host_rom.v" \
		-p "read_verilog -sv rtl/usb_hid_host.v" \
		-p "read_verilog -sv rtl/hid_uart_reporter.v" \
		-p "read_verilog -sv rtl/uart_tx.v" \
		-p "read_verilog -sv rtl/top.v" \
		-p "ls" \
		-p "hierarchy -top $(TOP) -check"

# Print a resource summary for the current RTL without running nextpnr.
.PHONY: yosys-stat
yosys-stat: $(SOURCES) $(ROM_INIT)
	@echo "  YOSYS STAT"
	$(QUIET)cd "$(ROOT)"; $(YOSYS) $(YOSYS_FLAGS) -l $(TOP).yosys.stat.log \
		-p "read_verilog -lib $(ICE40_CELLS_SIM)" \
		-p "read_verilog -sv rtl/pll.v" \
		-p "read_verilog -sv rtl/usb_io.v" \
		-p "read_verilog -sv $(ROM_MEM_DEFINE) rtl/usb_hid_host_rom.v" \
		-p "read_verilog -sv rtl/usb_hid_host.v" \
		-p "read_verilog -sv rtl/hid_uart_reporter.v" \
		-p "read_verilog -sv rtl/uart_tx.v" \
		-p "read_verilog -sv rtl/top.v" \
		-p "hierarchy -top $(TOP) -check" \
		-p "stat"

# Run synth_ice40 and verify the ROM maps into iCE40 EBR (SB_RAM40_4K).
.PHONY: yosys-synth-check
yosys-synth-check: $(SOURCES) $(ROM_INIT)
	@echo "  YOSYS SYNTH CHECK"
	$(QUIET)cd "$(ROOT)"; $(YOSYS) $(YOSYS_FLAGS) -l $(TOP).yosys.synth_check.log \
		-p "read_verilog -lib $(ICE40_CELLS_SIM)" \
		-p "read_verilog -sv rtl/pll.v" \
		-p "read_verilog -sv rtl/usb_io.v" \
		-p "read_verilog -sv $(ROM_MEM_DEFINE) rtl/usb_hid_host_rom.v" \
		-p "read_verilog -sv rtl/usb_hid_host.v" \
		-p "read_verilog -sv rtl/hid_uart_reporter.v" \
		-p "read_verilog -sv rtl/uart_tx.v" \
		-p "read_verilog -sv rtl/top.v" \
		-p "hierarchy -top $(TOP) -check" \
		-p "synth_ice40 -top $(TOP)" \
		-p "select -assert-count 1 t:SB_RAM40_4K" \
		-p "stat"

# Synthesis: Verilog -> JSON netlist
$(TOP).json: $(SOURCES) $(ROM_INIT)
	@echo "  SYN   $@"
	$(QUIET)cd "$(ROOT)"; $(YOSYS) $(YOSYS_FLAGS) -l $(TOP).yosys.log \
		-p "read_verilog -lib $(ICE40_CELLS_SIM)" \
		-p "read_verilog -sv rtl/pll.v" \
		-p "read_verilog -sv rtl/usb_io.v" \
		-p "read_verilog -sv $(ROM_MEM_DEFINE) rtl/usb_hid_host_rom.v" \
		-p "read_verilog -sv rtl/usb_hid_host.v" \
		-p "read_verilog -sv rtl/hid_uart_reporter.v" \
		-p "read_verilog -sv rtl/uart_tx.v" \
		-p "read_verilog -sv rtl/top.v" \
		-p "hierarchy -top $(TOP) -check" \
		-p "synth_ice40 -json $@"

# Place and route: JSON + PCF -> ASC
$(TOP).asc: $(TOP).json $(PCF)
	@echo "  PNR   $@"
	$(QUIET)$(NEXTPNR) $(PNR_FLAGS) \
		--$(DEVICE) \
		--package $(PACKAGE) \
		--json $< \
		--pcf $(PCF) \
		--pcf-allow-unconstrained \
		--placer heap \
		--router router2 \
		--timing-allow-fail \
		--asc $@

# Bitstream packing: ASC -> BIN
$(TOP).bin: $(TOP).asc
	@echo "  PACK  $@"
	$(QUIET)$(ICEPACK) $< $@

# -----------------------------------------------------------------------------
# Utility targets
# -----------------------------------------------------------------------------

# Flash to iCEbreaker
.PHONY: prog
prog: $(TOP).bin
	@echo "  PROG  $<"
	$(QUIET)$(ICEPROG) $<

# Print resource and timing summary
.PHONY: utilisation
utilisation: $(TOP).asc
	@echo "  UTIL"
	$(QUIET)$(NEXTPNR) \
		--$(DEVICE) \
		--package $(PACKAGE) \
		--json $(TOP).json \
		--pcf $(PCF) \
		--asc /dev/null \
		--report /dev/stdout 2>&1 | grep -E "ICESTORM|SB_IO|SB_PLL|Timing" || true

# Sanity-check that the toolchain is installed and on PATH.
.PHONY: toolcheck
toolcheck:
	@echo "  TOOLCHECK"
	@command -v $(YOSYS) >/dev/null 2>&1 || (echo "ERROR: $(YOSYS) not found in PATH"; exit 1)
	@command -v $(NEXTPNR) >/dev/null 2>&1 || (echo "ERROR: $(NEXTPNR) not found in PATH"; exit 1)
	@command -v $(ICEPACK) >/dev/null 2>&1 || (echo "ERROR: $(ICEPACK) not found in PATH"; exit 1)
	@$(YOSYS) -V
	@$(NEXTPNR) --version
	@echo "NOTE: $(ICEPROG) is only required for 'make prog'"
	@command -v $(ICEPROG) >/dev/null 2>&1 && echo "Found $(ICEPROG)" || echo "WARN: $(ICEPROG) not found (ok unless flashing)"

# Remove build artifacts
.PHONY: clean
clean:
	@echo "  CLEAN"
	$(QUIET)rm -f $(TOP).json $(TOP).asc $(TOP).bin \
		$(TOP).yosys.log $(TOP).yosys.ls.log $(TOP).yosys.stat.log \
		$(TOP).yosys.synth_check.log
	$(QUIET)rm -f $(ROM_INIT)
