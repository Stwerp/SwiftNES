# Contributing

## Prerequisites

This project uses the open-source iCE40 toolchain. You will need:

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases) —
  bundles Yosys, nextpnr-ice40, and IceStorm in a single download
- [iCEbreaker v1.1a](https://1bitsquared.com/products/icebreaker) —
  iCE40UP5K development board

OSS CAD Suite is the recommended installation method. Do not install Yosys,
nextpnr, or IceStorm individually from system packages — versions from apt/brew
are often too old and will produce incorrect results.

## Toolchain setup

Download and extract OSS CAD Suite for your platform from the releases page.
The Makefile expects it at `~/oss-cad-suite` by default. If you install it
elsewhere, set `OSS_CAD_SUITE_PATH` in your shell rc:
```bash
export OSS_CAD_SUITE_PATH=/path/to/oss-cad-suite
```

Verify the toolchain is working:
```bash
source ~/oss-cad-suite/environment
yosys --version
nextpnr-ice40 --version
iceprog --version
```

## Building
```bash
# Build bitstream
make

# Verbose output (full Yosys and nextpnr logs)
make V=1

# Flash to iCEbreaker
make prog

# Check resource and timing utilisation
make utilisation

# Clean build artefacts
make clean
```