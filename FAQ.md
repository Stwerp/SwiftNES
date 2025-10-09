# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is SwiftNES?
**A:** SwiftNES is an FPGA-based adapter that lets you use a keyboard (USB or PS/2) as an NES controller. It translates keyboard key presses into the serial protocol that NES consoles understand.

### Q: Do I need programming experience to use this?
**A:** No programming experience is needed to **use** the project. You just need to:
1. Install the FPGA toolchain (simple commands)
2. Build and program the FPGA (one command)
3. Connect the hardware

However, customizing key mappings requires editing Verilog files (but examples are provided).

### Q: Which version should I build: USB or PS/2?
**A:** **PS/2 version is strongly recommended** because:
- It's fully implemented and tested
- PS/2 protocol is simpler and more reliable
- You can use a USB keyboard with a PS/2 adapter
- The USB version needs significant additional development

### Q: Can I use a modern USB keyboard?
**A:** Yes, but you need a USB-to-PS/2 adapter. Many keyboards support PS/2 mode through these adapters. Check your keyboard specifications or just try it - adapters are cheap (~$5).

## Hardware Questions

### Q: Where can I buy the iCEBreaker board?
**A:** Official sources:
- 1BitSquared: https://1bitsquared.com/products/icebreaker
- Crowd Supply: https://www.crowdsupply.com/1bitsquared/icebreaker-fpga
- Price: Around $60-80

### Q: Can I use a different FPGA board?
**A:** Yes, but you'll need to:
1. Modify pin constraints in `constraints/icebreaker.pcf`
2. Ensure your board has an iCE40 FPGA (or port to different architecture)
3. Have at least 2 PMOD ports or equivalent GPIO

Other compatible boards: TinyFPGA BX, UPduino, iCEStick (with modifications)

### Q: What's a PMOD?
**A:** PMOD (Peripheral Module) is a standard connector interface with 0.1" pin headers. It's an easy way to connect external devices to FPGA boards. Most FPGA dev boards have PMOD connectors.

### Q: Will this damage my NES console?
**A:** No, if you follow the connections correctly. The adapter only:
- Reads Clock and Latch signals (inputs)
- Sends Data signal (output at safe voltage levels)
- Uses the same +5V power the NES provides

Always double-check connections before powering on.

### Q: Do I need 5V or 3.3V power?
**A:** 
- **NES provides**: 5V (but accepts 3.3V data signals in most cases)
- **iCEBreaker I/O**: 3.3V (but 5V tolerant on inputs)
- **PS/2 keyboards**: Usually work with 3.3V or 5V
- **Recommendation**: Start with 3.3V from iCEBreaker

### Q: Can I make this wireless?
**A:** Not with the current design, but possible extensions:
- Add Bluetooth keyboard receiver module
- Use ESP32 or similar with WiFi
- Add wireless USB dongle support (requires USB implementation)

## Software Questions

### Q: What operating systems are supported for building?
**A:** The FPGA toolchain (Yosys, nextpnr) runs on:
- Linux (Ubuntu, Debian, Fedora, Arch, etc.) - **Recommended**
- macOS (via Homebrew)
- Windows (via WSL2 or MSYS2)

### Q: Do I need Lattice Diamond or other commercial tools?
**A:** No! This project uses **100% open-source tools**:
- Yosys (synthesis)
- nextpnr-ice40 (place and route)
- icepack (bitstream generation)
- iceprog (programming)

All are free and work on Linux/macOS/Windows.

### Q: How long does it take to build?
**A:** On a typical modern computer:
- Synthesis: 5-15 seconds
- Place and route: 10-30 seconds
- Total build time: Under 1 minute

### Q: Can I simulate the design before building?
**A:** Yes! There's a testbench in `sim/nes_controller_interface_tb.v`. You need:
```bash
sudo apt-get install iverilog gtkwave
cd sim
iverilog -o test nes_controller_interface_tb.v ../rtl/nes_controller_interface.v
vvp test
gtkwave nes_controller_interface_tb.vcd
```

## Usage Questions

### Q: Can I use arrow keys instead of WASD?
**A:** 
- **USB version**: Yes, arrow keys are mapped (when USB is fully implemented)
- **PS/2 version**: Arrow keys send extended scancodes - not currently supported
- **Recommendation**: Use WASD for now, or modify the PS/2 mapper to handle extended codes

### Q: Can I change the key mappings?
**A:** Yes! Edit the scancode constants in:
- USB version: `rtl/keyboard_to_nes.v`
- PS/2 version: `rtl/ps2_to_nes.v`

See the USB HID or PS/2 scancode tables in the documentation.

### Q: Does this work with SNES?
**A:** Not yet, but it could be extended:
- SNES uses similar protocol with 12 buttons instead of 8
- Would need to add support for L/R shoulder buttons and X/Y buttons
- Pull requests welcome!

### Q: What's the input latency?
**A:** Very low:
- Keyboard to FPGA: <1ms (PS/2) or variable (USB, when implemented)
- FPGA processing: <1μs (pure hardware)
- NES reads controller: Every 16.7ms (NTSC) or 20ms (PAL)
- **Total effective latency**: One NES frame (~16.7ms)

This is comparable to or better than original NES controllers.

### Q: Can I use this with emulators?
**A:** Not directly - this is hardware for real NES consoles. For emulators:
- Just use your keyboard directly with the emulator
- Or use a USB controller
- This project is specifically for playing on real NES hardware with a keyboard

## Troubleshooting

### Q: The FPGA programming fails with "device not found"
**A:** 
1. Check USB connection
2. Try `lsusb` to see if iCEBreaker is detected
3. Check permissions: `sudo chmod 666 /dev/ttyACM0`
4. Try different USB port or cable
5. Install FTDI drivers if needed

### Q: Keys aren't registering in the NES
**A:** 
1. Check green LED - does it light when you press keys?
2. Verify NES connections with multimeter
3. Test with original NES controller to ensure console works
4. Check DATA signal with oscilloscope/logic analyzer if available
5. Verify keyboard works on PC

### Q: Some keys work but others don't
**A:** 
1. Check your keyboard's scancode format
2. Different keyboards may use different scancodes
3. PS/2 keyboards use Set 2 scancodes (most common)
4. You may need to update the scancode mappings

### Q: Build fails with synthesis errors
**A:**
1. Ensure you have latest toolchain versions
2. Check that all source files are present
3. Try `make clean` then `make` again
4. Check Verilog syntax in error messages

## Development Questions

### Q: How can I help complete the USB implementation?
**A:** Great! See `docs/USB_IMPLEMENTATION.md` for details. Main tasks:
1. Implement USB PHY layer (NRZI, bit stuffing)
2. Add USB packet layer (PIDs, CRC)
3. Implement enumeration sequence
4. Add HID report parsing
Or, contribute a microcontroller bridge design!

### Q: Can I add support for other controllers?
**A:** Yes! The NES interface module is reusable. You could add:
- SNES controller (12 buttons)
- Game Boy controller (similar protocol)
- Atari joystick (simpler, just switches)
- Generic gamepad to NES adapter

### Q: What license is this under?
**A:** MIT License - you can use, modify, and distribute freely. See LICENSE file.

### Q: How can I contribute?
**A:** 
1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

Areas needing help:
- Complete USB implementation
- SNES support
- Better documentation
- More testbenches
- PCB designs for PMODs

## Fun Questions

### Q: Why would I want to use a keyboard with NES?
**A:** 
- Play NES at your desk without reaching for controller
- Use mechanical keyboard for better tactile feedback
- Accessibility - easier for some people than holding controller
- Speedrunning - some runners prefer keyboard
- Because you can! 🎮

### Q: What games work best with keyboard?
**A:** Games that don't require precise analog control:
- **Excellent**: Mega Man, Contra, Castlevania, Metroid
- **Good**: Super Mario Bros, Zelda, Final Fantasy
- **Challenging**: Games requiring rapid diagonal inputs

### Q: Has anyone actually used this?
**A:** This is a new project! You could be the first. Please share your experience!

### Q: What's next for SwiftNES?
**A:** Possible future features:
- Complete USB host implementation
- SNES support (12 buttons)
- Wireless keyboard support
- Multiple controller ports
- Turbo/auto-fire buttons
- Keyboard macro recording

## Still Have Questions?

1. Check the documentation in `docs/` folder
2. Read the source code comments
3. Open an issue on GitHub
4. Contact the maintainers

Happy gaming! 🎮✨
