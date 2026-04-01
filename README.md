# SwiftNES
Keyboard interface for NES/SNES hardware

## Building (Linux)

This project expects the open-source iCE40 toolchain (`yosys`, `nextpnr-ice40`, `icepack`, and optionally `iceprog`) to be available on your `PATH`.

Quick sanity check:
```sh
make toolcheck
```

Build bitstream:
```sh
make
```
