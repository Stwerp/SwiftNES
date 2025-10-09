# Bill of Materials (BOM)

## Required Components

### 1. FPGA Development Board
| Item | Specification | Quantity | Estimated Cost | Source |
|------|--------------|----------|----------------|--------|
| Lattice iCEBreaker | iCE40UP5K FPGA board | 1 | $60-80 | [1BitSquared](https://1bitsquared.com/products/icebreaker), [Crowd Supply](https://www.crowdsupply.com/1bitsquared/icebreaker-fpga) |

### 2. Keyboard (Choose ONE Option)

#### Option A: PS/2 Version (Recommended)
| Item | Specification | Quantity | Estimated Cost | Source |
|------|--------------|----------|----------------|--------|
| PS/2 Keyboard | Any PS/2 keyboard with 6-pin Mini-DIN | 1 | $5-15 | eBay, local surplus |
| **OR** USB Keyboard + Adapter | USB keyboard with USB-to-PS/2 adapter | 1 | $10-20 | Amazon, eBay |
| PS/2 Extension Cable | 6-pin Mini-DIN, male-female | 1 (optional) | $3-5 | Amazon, eBay |

#### Option B: USB Version (Requires Additional Development)
| Item | Specification | Quantity | Estimated Cost | Source |
|------|--------------|----------|----------------|--------|
| USB Keyboard | Any USB HID keyboard | 1 | $10-30 | Amazon, local store |
| USB Host PMOD | USB-A host with 3.3V/5V support | 1 | $15-25 | Custom build required |
| **OR** MCU Bridge | STM32/RP2040 with USB host | 1 | $5-15 | AliExpress, Adafruit |

### 3. NES Connection
| Item | Specification | Quantity | Estimated Cost | Source |
|------|--------------|----------|----------------|--------|
| NES Controller Cable | 7-pin extension cable | 1 | $3-8 | Amazon, eBay, RetroGameRepair |
| **OR** NES Controller Port | Female 7-pin connector | 1 | $2-5 | Console5, eBay |
| **OR** NES to PMOD Adapter | Custom PCB | 1 | DIY | See below |

### 4. Cables and Connectors
| Item | Specification | Quantity | Estimated Cost | Source |
|------|--------------|----------|----------------|--------|
| USB Cable | Micro USB or USB-C (for iCEBreaker programming) | 1 | $3-5 | Included with board |
| PMOD Headers | 2x6 pin, 0.1" pitch (if making custom PMODs) | 2 | $1-2 | DigiKey, Mouser |
| Jumper Wires | Male-female, 6" length | 10-20 | $5 | Amazon, Adafruit |

### 5. Optional Components
| Item | Purpose | Quantity | Estimated Cost | Source |
|------|---------|----------|----------------|--------|
| Breadboard | Prototyping connections | 1 | $5-10 | Amazon, Adafruit |
| Level Shifter | 3.3V ↔ 5V conversion (optional) | 1 | $3-5 | Adafruit, SparkFun |
| Pull-up Resistors | 4.7kΩ - 10kΩ for data lines | 2-4 | $0.50 | DigiKey, Mouser |
| Multimeter | Testing connections and voltages | 1 | $15-30 | Amazon, Harbor Freight |
| Soldering Iron | If making permanent connections | 1 | $20-50 | Amazon |

## Total Cost Estimate

### Minimum Cost (PS/2 Version, No Extras)
- iCEBreaker board: $65
- PS/2 keyboard (used): $5
- NES controller cable (used): $4
- Jumper wires: $5
- **Total: ~$79**

### Typical Cost (PS/2 Version with Tools)
- iCEBreaker board: $70
- USB keyboard + PS/2 adapter: $15
- NES controller extension cable: $6
- Breadboard and jumpers: $10
- Multimeter: $20
- **Total: ~$121**

### Advanced Cost (USB Version with MCU Bridge)
- iCEBreaker board: $70
- USB keyboard: $15
- MCU board (RP2040): $10
- NES controller cable: $6
- Prototyping supplies: $15
- **Total: ~$116**

## Where to Source Components

### Official iCEBreaker
- **1BitSquared**: https://1bitsquared.com/products/icebreaker
- **Crowd Supply**: https://www.crowdsupply.com/1bitsquared/icebreaker-fpga

### Keyboards
- **PS/2 Keyboards**: 
  - eBay (search "PS/2 keyboard")
  - Local thrift stores
  - Surplus electronics stores
- **USB-to-PS/2 Adapters**:
  - Amazon (search "USB to PS/2 adapter")
  - Note: Not all adapters work - keyboard must support PS/2 protocol

### NES Cables and Connectors
- **Console5**: https://console5.com/ (replacement parts)
- **RetroGameRepair**: Various suppliers
- **eBay**: Search "NES controller extension cable"
- **AliExpress**: Cheaper but slower shipping

### Electronic Components
- **DigiKey**: https://www.digikey.com/
- **Mouser**: https://www.mouser.com/
- **SparkFun**: https://www.sparkfun.com/
- **Adafruit**: https://www.adafruit.com/

## DIY NES to PMOD Adapter

If you want to make a custom adapter board:

### Materials Needed
- 7-pin female connector (NES controller port style)
- 2x6 PMOD header (male, 0.1" pitch)
- Small perfboard or custom PCB
- Wire for connections
- Soldering equipment

### Connections
```
NES Port → PMOD
Pin 1 (GND)    → Pin 4, 11 (GND)
Pin 2 (CLOCK)  → Pin 1
Pin 3 (LATCH)  → Pin 2
Pin 4 (DATA)   → Pin 3
Pin 7 (+5V)    → Pin 12 (VCC) or separate power
```

## Notes on Compatibility

### PS/2 Keyboards
- Most PS/2 keyboards will work
- Some USB keyboards support PS/2 mode with adapter
- Test with adapter before committing to permanent connection

### USB Keyboards (Future)
- Must be USB HID class
- Low-speed or full-speed USB
- Some wireless keyboards may not work

### NES Consoles
- Works with original NES (NTSC and PAL)
- May work with NES clones (compatibility varies)
- Not compatible with Famicom without adapter (different connector)

## Alternatives and Substitutions

### Instead of iCEBreaker
Other iCE40 boards may work with pin assignment changes:
- iCEStick (Lattice iCE40HX1K)
- TinyFPGA BX (iCE40LP8K)
- UPduino (iCE40UP5K)

### Instead of Real Hardware
For development/testing:
- Simulation with Icarus Verilog (free)
- FPGA emulation on larger FPGA boards
- Microcontroller-based solution (Arduino, ESP32)

## Safety and Testing Equipment

Highly recommended for first-time builders:
1. **Multimeter** - Test voltages and continuity ($15-30)
2. **Anti-static wrist strap** - Protect FPGA ($5)
3. **Good lighting** - See small pins and connections
4. **Magnifying glass** - Inspect solder joints
5. **Label maker** - Mark cables and connections ($10-20)

## Warranty and Support

- iCEBreaker comes with limited warranty from manufacturer
- Most components have 30-day return policies
- Check seller ratings and reviews before purchasing
- Keep receipts for expensive components

## Recommended First Order

For someone starting from scratch (PS/2 version):
1. ✅ iCEBreaker FPGA board
2. ✅ USB keyboard with PS/2 adapter (most versatile)
3. ✅ NES controller extension cable
4. ✅ Breadboard and jumper wire kit
5. ✅ Basic multimeter
6. ⏸️ Soldering iron (only if making permanent)

**Estimated total: $105-125**

This allows you to:
- Build and test the PS/2 version
- Use the USB keyboard on PC when not testing
- Prototype without permanent connections
- Debug and verify with multimeter
