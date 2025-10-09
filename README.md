# SwiftNES
USB/PS2 Keyboard to NES Controller Interface

SwiftNES is a hardware adapter that allows you to use a standard USB or PS/2 keyboard as an NES (Nintendo Entertainment System) controller. Built on the Lattice iCEBreaker FPGA board with an iCE40UP5K chip, it translates keyboard inputs into the serial protocol used by NES controllers.

**🚀 New to the project?** Start with the [Quick Start Guide](QUICKSTART.md)!

## Features

- **Dual Keyboard Support**: Works with both USB HID and PS/2 keyboards
- **NES Controller Emulation**: Full 8-button controller support (A, B, Select, Start, D-Pad)
- **Open Source**: Built with open-source FPGA tools (Yosys, nextpnr)
- **Low Latency**: Hardware-based translation for minimal input lag
- **Status LEDs**: Visual feedback for connection and button states
- **Configurable Key Mapping**: Easy-to-modify keyboard layout

## Hardware Requirements

- Lattice iCEBreaker FPGA board (iCE40UP5K)
- **Option A**: USB Host PMOD module + USB keyboard
- **Option B**: PS/2 PMOD or adapter + PS/2 keyboard (or USB keyboard with PS/2 adapter)
- NES controller cable or connector

**Note**: PS/2 version is recommended for beginners as it's much simpler to implement and test.

See [Hardware Setup Guide](docs/HARDWARE_SETUP.md) for detailed connection instructions.

## Key Mapping

Default keyboard layout (both USB and PS/2):

| Keyboard Key | NES Button | USB Scancode | PS/2 Scancode |
|-------------|------------|--------------|---------------|
| W           | D-Pad Up   | 0x1A         | 0x1D          |
| S           | D-Pad Down | 0x16         | 0x1B          |
| A           | D-Pad Left | 0x04         | 0x1C          |
| D           | D-Pad Right| 0x07         | 0x23          |
| K or Space  | A Button   | 0x0E / 0x2C  | 0x42 / 0x29   |
| J           | B Button   | 0x0D         | 0x3B          |
| Enter       | Start      | 0x28         | 0x5A          |
| Right Shift | Select     | 0xE5         | 0x59          |

**Note**: USB version also supports arrow keys (↑↓←→) for D-Pad.

## Building the Project

### Prerequisites

Install the open-source iCE40 FPGA toolchain:

```bash
# On Ubuntu/Debian
sudo apt-get install yosys nextpnr-ice40 fpga-icestorm

# On macOS with Homebrew
brew install icestorm yosys nextpnr-ice40
```

### Build Steps

```bash
# Clone the repository
git clone https://github.com/Stwerp/SwiftNES.git
cd SwiftNES

# Build the bitstream for USB version (default)
make

# OR build for PS/2 version (recommended for beginners)
make ps2

# Program the iCEBreaker board
make prog
```

### Build Targets

- `make` or `make all`: Build USB version bitstream
- `make ps2`: Build PS/2 version bitstream (simpler, recommended)
- `make prog`: Program the FPGA
- `make timing`: Run timing analysis
- `make clean`: Remove build artifacts
- `make help`: Show help message

## Usage

### USB Version
1. Connect the USB keyboard to the USB Host PMOD on PMOD1A
2. Connect the NES controller port to PMOD2A
3. Power on the iCEBreaker via USB
4. Wait for the red LED to turn off (keyboard connected)
5. Press keys on the keyboard - the green LED lights when buttons are pressed
6. The NES console should recognize the adapter as a controller

### PS/2 Version
1. Connect the PS/2 keyboard (or USB keyboard with PS/2 adapter) to PMOD1A
2. Connect the NES controller port to PMOD2A
3. Power on the iCEBreaker via USB
4. Press keys on the keyboard - the green LED lights when buttons are pressed
5. The NES console should recognize the adapter as a controller

**Important Note**: The USB version currently has a simplified USB host implementation (placeholder state machine). For immediate use, the **PS/2 version is recommended** as it has a complete, working implementation. See [USB Implementation Notes](docs/USB_IMPLEMENTATION.md) for details on completing the USB version.

## Project Structure

```
SwiftNES/
├── rtl/                              # Verilog RTL source files
│   ├── top.v                         # Top-level module (USB version)
│   ├── top_ps2.v                     # Top-level module (PS/2 version)
│   ├── usb_hid_host.v               # USB HID host controller (WIP)
│   ├── ps2_keyboard_host.v          # PS/2 keyboard interface (complete)
│   ├── keyboard_to_nes.v            # USB key mapping logic
│   ├── ps2_to_nes.v                 # PS/2 key mapping logic
│   └── nes_controller_interface.v   # NES protocol implementation
├── constraints/
│   └── icebreaker.pcf               # Pin constraints for iCEBreaker
├── sim/                              # Simulation testbenches
│   └── nes_controller_interface_tb.v
├── docs/                             # Documentation
│   ├── NES_PROTOCOL.md              # NES controller protocol details
│   ├── HARDWARE_SETUP.md            # Hardware setup guide
│   └── USB_IMPLEMENTATION.md        # USB implementation notes
├── Makefile                          # Build system
└── README.md                         # This file
```

## Architecture

The design consists of three main modules:

### USB Version (Work in Progress)
1. **USB HID Host** (`usb_hid_host.v`): Simplified USB host - requires full implementation
2. **Keyboard Mapper** (`keyboard_to_nes.v`): Translates USB HID scancodes to NES buttons
3. **NES Controller Interface** (`nes_controller_interface.v`): Implements NES serial protocol

### PS/2 Version (Complete and Working)
1. **PS/2 Host** (`ps2_keyboard_host.v`): Complete PS/2 keyboard protocol implementation
2. **PS/2 Mapper** (`ps2_to_nes.v`): Translates PS/2 scancodes to NES buttons
3. **NES Controller Interface** (`nes_controller_interface.v`): Implements NES serial protocol

See [NES Protocol Documentation](docs/NES_PROTOCOL.md) for technical details on the controller interface.
See [USB Implementation Notes](docs/USB_IMPLEMENTATION.md) for information on completing the USB version.

## Customization

### Changing Key Mappings

**For USB version**, edit `rtl/keyboard_to_nes.v`:
```verilog
localparam KEY_W = 8'h1A;  // USB HID scancode
```

**For PS/2 version**, edit `rtl/ps2_to_nes.v`:
```verilog
localparam PS2_W = 8'h1D;  // PS/2 scancode
```

References:
- USB HID scancodes: [USB HID Usage Tables](https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf) (Page 0x07)
- PS/2 scancodes: [PS/2 Scancode Set 2](https://wiki.osdev.org/PS/2_Keyboard)

### Pin Assignments

To use different PMOD connectors, edit `constraints/icebreaker.pcf`:

```
set_io PMOD1A_1 4   # Change pin numbers as needed
```

## Limitations

### USB Version
- USB implementation is simplified (placeholder state machine)
- Full USB enumeration is not implemented
- Low-speed USB only (1.5 Mbps)
- May not work with all keyboards
- **Recommended to use PS/2 version or add microcontroller bridge** (see USB_IMPLEMENTATION.md)

### PS/2 Version
- Requires PS/2 keyboard or USB-to-PS/2 adapter
- Extended keys (arrow keys, etc.) not currently mapped
- No support for special keys or modifiers beyond those mapped

### Both Versions
- WASD recommended for directional control
- No turbo button functionality

## Future Enhancements

- [ ] Complete USB host protocol implementation
- [ ] SNES controller support (12-button)
- [ ] Configuration via DIP switches or serial interface
- [ ] Multiple controller support
- [ ] Turbo button functionality

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## References

- [Quick Start Guide](QUICKSTART.md) - **Start here!**
- [NES Controller Protocol](docs/NES_PROTOCOL.md)
- [Hardware Setup Guide](docs/HARDWARE_SETUP.md)
- [Connection Diagrams](docs/CONNECTIONS.md)
- [USB Implementation Notes](docs/USB_IMPLEMENTATION.md)
- [iCEBreaker Documentation](https://icebreaker-fpga.github.io/icebreaker/)
- [USB HID Specification](https://www.usb.org/hid)
- [PS/2 Protocol](https://wiki.osdev.org/PS/2_Keyboard)
- [NESdev Wiki](https://www.nesdev.org/)

## Acknowledgments

- iCEBreaker board design by Piotr Esden-Tempski
- Open-source FPGA tools by Clifford Wolf and contributors
- NES community for protocol documentation
