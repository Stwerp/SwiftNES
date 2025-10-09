# Connection Diagrams

## PS/2 Version Connections

### PMOD1A - PS/2 Keyboard

```
iCEBreaker PMOD1A          PS/2 Mini-DIN 6 Connector
┌─────────────┐            ┌─────────────┐
│  Pin 1 (4)  │───────────→│  Pin 5 CLK  │
│  Pin 2 (2)  │───────────→│  Pin 1 DATA │
│  Pin 3 (47) │───────────→│  Pin 4 VCC  │ (5V or 3.3V)
│  Pin 4 (45) │───────────→│  Pin 3 GND  │
└─────────────┘            └─────────────┘

PS/2 Mini-DIN 6 Pin Layout (looking at female connector on keyboard cable):
        ___
      /  6  \
     | 5   1 |
      | 4 2 |
       \ 3 /
        ---
Pin 1: DATA
Pin 2: Not connected
Pin 3: GND
Pin 4: VCC (5V)
Pin 5: CLK
Pin 6: Not connected
```

### PMOD2A - NES Controller Port

```
iCEBreaker PMOD2A          NES Controller Port (7-pin)
┌─────────────┐            ┌─────────────┐
│  Pin 1 (43) │←───────────│  Pin 2 CLK  │
│  Pin 2 (38) │←───────────│  Pin 3 LATCH│
│  Pin 3 (34) │───────────→│  Pin 4 DATA │
│  Pin 4 (31) │───────────→│  Pin 1 GND  │
│  Pin 7 (42) │←───────────│  Pin 7 VCC  │ (5V from NES)
└─────────────┘            └─────────────┘

NES Controller Port (looking at front of NES console):
     ___
   /     \
  | 1 2 3 |
   | 4 5 |
    |6 7|
     ---
Pin 1: GND
Pin 2: CLOCK (output from NES)
Pin 3: LATCH (output from NES)
Pin 4: DATA (input to NES) ← Our output
Pin 5: Not used
Pin 6: Not used
Pin 7: +5V (from NES)
```

## USB Version Connections (When Implemented)

### PMOD1A - USB Host PMOD

```
iCEBreaker PMOD1A          USB Type-A Host
┌─────────────┐            ┌─────────────┐
│  Pin 1 (4)  │←──────────→│  D+ (pin 3) │
│  Pin 2 (2)  │←──────────→│  D- (pin 2) │
│  Pin 3 (47) │───────────→│  VCC (pin 1)│ (5V preferred)
│  Pin 4 (45) │───────────→│  GND (pin 4)│
└─────────────┘            └─────────────┘

USB Type-A Connector Pinout (looking into female connector):
┌─────────────────┐
│ ┌─┐         ┌─┐ │
│ │1│         │4│ │
│ └─┘         └─┘ │
│ ┌─┐         ┌─┐ │
│ │2│         │3│ │
│ └─┘         └─┘ │
└─────────────────┘
Pin 1: VCC (+5V)
Pin 2: D-
Pin 3: D+
Pin 4: GND
```

### NES Controller Port (same as PS/2 version)
See PMOD2A diagram above.

## Complete System Diagram - PS/2 Version

```
┌──────────────────────────────────────────────────────────────┐
│                    NES Console                                │
│                                                               │
│  Controller Port ───────────────────────┐                    │
└──────────────────────────────────────────┼────────────────────┘
                                           │
                      Clock, Latch ────────┤
                      Data ←───────────────┤
                      +5V, GND ────────────┤
                                           │
┌──────────────────────────────────────────┼────────────────────┐
│  Lattice iCEBreaker FPGA Board           │                    │
│                                          │                    │
│  ┌────────────────────────────────┐     │                    │
│  │    iCE40UP5K FPGA              │     │                    │
│  │                                │     │                    │
│  │  ┌──────────────────────┐     │     │                    │
│  │  │ NES Controller       │←────┼─────┘ PMOD2A             │
│  │  │ Interface            │     │                           │
│  │  └──────┬───────────────┘     │                           │
│  │         │                      │                           │
│  │  ┌──────┴───────────────┐     │                           │
│  │  │ PS/2 to NES Mapper   │     │                           │
│  │  └──────┬───────────────┘     │                           │
│  │         │                      │                           │
│  │  ┌──────┴───────────────┐     │                           │
│  │  │ PS/2 Keyboard Host   │←────┼─────┐ PMOD1A              │
│  │  └──────────────────────┘     │     │                     │
│  │                                │     │                     │
│  └────────────────────────────────┘     │                     │
│                                          │                     │
│  LEDs: [RED] [GREEN]                    │                     │
│  BTN:  [RESET]                          │                     │
│  USB Programming Port                   │                     │
└──────────────────────────────────────────┼─────────────────────┘
                                           │
                      Clock, Data ─────────┤
                      +5V/3.3V, GND ───────┤
                                           │
┌──────────────────────────────────────────┴─────────────────────┐
│                    PS/2 Keyboard                               │
│                    (or USB keyboard with PS/2 adapter)         │
└────────────────────────────────────────────────────────────────┘
```

## Signal Level Compatibility

### PS/2 Keyboard Interface
- **Logic Levels**: PS/2 uses 5V logic, but most keyboards are compatible with 3.3V
- **iCE40 I/O**: 3.3V tolerant (can handle 3.3V and 5V with proper configuration)
- **Recommendation**: Test with 3.3V first; some keyboards may need 5V

### NES Controller Interface
- **Logic Levels**: NES uses 5V logic
- **iCE40 I/O**: Can be configured as 5V tolerant inputs
- **Data Output**: Use 3.3V output with series resistor (100Ω) or level shifter
- **Note**: Most NES consoles will accept 3.3V logic on DATA input

### USB Interface (When Implemented)
- **Logic Levels**: USB uses 3.3V signaling
- **Power**: USB keyboards expect 5V power
- **Level Shifters**: May be needed for D+/D- signals if using 5V power

## Recommended PMOD Hardware

### For PS/2 Version
- Option 1: Make your own with a PS/2 6-pin Mini-DIN connector
- Option 2: Use a breadboard adapter
- Option 3: Modify a PS/2 extension cable

### For NES Connection
- Option 1: NES controller extension cable (cut and solder to PMOD)
- Option 2: NES controller breakout board
- Option 3: Direct connection to NES controller port with wire

### Safety Notes
⚠️ Always double-check connections before powering on
⚠️ Use a multimeter to verify voltage levels
⚠️ Ensure proper grounding between all devices
⚠️ Don't hot-plug connections to the NES console
