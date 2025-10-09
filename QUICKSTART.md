# Quick Start Guide

## For Beginners: PS/2 Version (Recommended)

The PS/2 version is **fully functional** and easier to get working. Follow these steps:

### What You Need
1. Lattice iCEBreaker FPGA board
2. PS/2 keyboard OR USB keyboard with USB-to-PS/2 adapter (purple connector)
3. NES controller extension cable (to connect to your NES console)
4. USB cable for programming the iCEBreaker

### Steps

1. **Install the toolchain** (one-time setup):
   ```bash
   # Ubuntu/Debian
   sudo apt-get install yosys nextpnr-ice40 fpga-icestorm
   
   # macOS
   brew install icestorm yosys nextpnr-ice40
   ```

2. **Build and program**:
   ```bash
   git clone https://github.com/Stwerp/SwiftNES.git
   cd SwiftNES
   make ps2        # Build PS/2 version
   make prog       # Program the board
   ```

3. **Connect hardware**:
   - PS/2 keyboard → PMOD1A (pins 1=Clock, 2=Data, 3=VCC, 4=GND)
   - NES cable → PMOD2A (pins 1=Clock, 2=Latch, 3=Data, 4=GND, 7=VCC)
   - Power iCEBreaker via USB

4. **Test it**:
   - Green LED should light up when you press keys
   - Use WASD for movement, K for A, J for B, Enter for Start

## For Advanced Users: USB Version

The USB version has a **simplified placeholder** implementation and needs more work to be fully functional.

### Current Status
- Framework is in place
- State machine structure exists
- Full USB protocol stack needs implementation

### Options to Complete USB Version
1. **Implement full USB stack in Verilog** (significant effort)
2. **Use microcontroller bridge** (recommended - add MCU to handle USB, talk to FPGA via SPI)
3. **Use existing USB IP core** (may require licensing)

See [USB Implementation Guide](USB_IMPLEMENTATION.md) for detailed information.

### If You Want to Try USB Anyway
```bash
make            # Build USB version
make prog       # Program the board
```

**Note**: This will synthesize, but the USB enumeration is not complete, so it won't work with a real keyboard yet.

## Troubleshooting

### PS/2 Version

**Problem**: No response from keyboard
- Check that PS/2 clock and data are on correct pins
- Verify PS/2 keyboard is getting power (5V or 3.3V depending on keyboard)
- Try a different PS/2 keyboard
- Check connections with multimeter

**Problem**: NES doesn't recognize controller
- Verify NES console is powered and working (test with original controller)
- Check Clock, Latch, and Data connections
- Ensure proper ground connection between all devices
- Measure voltages: NES provides +5V on pin 7

**Problem**: Random button presses
- Add pull-up resistor on DATA line (4.7kΩ to 10kΩ)
- Check for loose connections
- Verify ground is solid

### Build Issues

**Problem**: `yosys: command not found`
- Toolchain not installed - follow step 1 above

**Problem**: Synthesis errors
- Check that you're using compatible versions of tools
- Try: `yosys --version`, `nextpnr-ice40 --version`

**Problem**: Programming fails
- Ensure iCEBreaker is connected via USB
- Check USB permissions: `sudo chmod 666 /dev/ttyACM0` (or similar)
- Try: `lsusb` to see if board is detected

## Key Mapping Quick Reference

```
╔════════════════════════════════════════╗
║  Keyboard          →    NES Button     ║
╠════════════════════════════════════════╣
║  W                 →    D-Pad Up       ║
║  S                 →    D-Pad Down     ║
║  A                 →    D-Pad Left     ║
║  D                 →    D-Pad Right    ║
║  K or Space        →    A Button       ║
║  J                 →    B Button       ║
║  Enter             →    Start          ║
║  Right Shift       →    Select         ║
╚════════════════════════════════════════╝
```

## Next Steps

- Test with your favorite NES games!
- Customize key mappings in `rtl/ps2_to_nes.v`
- Check the full documentation in `docs/` folder
- Consider contributing improvements to the USB implementation

## Getting Help

If you encounter issues:
1. Check the documentation in the `docs/` folder
2. Review the schematic and pin assignments
3. Open an issue on GitHub with details about your setup

Happy gaming! 🎮
