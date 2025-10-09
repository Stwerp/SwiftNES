# Hardware Setup Guide

## Components Required

1. **Lattice iCEBreaker FPGA Board**
   - iCE40UP5K FPGA
   - 12MHz oscillator
   - PMOD connectors
   - USB programming interface

2. **USB Host PMOD**
   - USB Type-A host connector
   - Level shifters (USB uses 3.3V, but many keyboards expect 5V)
   - Examples:
     - Digilent PMOD USBUART (modified for host mode)
     - Custom USB host PMOD

3. **NES Controller Cable**
   - 7-pin connector (can use original NES controller extension cable)
   - Or breadboard connections to NES console

4. **USB Keyboard**
   - Any standard USB HID keyboard
   - Low-speed or full-speed USB compatible

## Hardware Connections

### PMOD1A - USB Host Connection
```
Pin 1 (PMOD1A_1): USB D+
Pin 2 (PMOD1A_2): USB D-
Pin 3 (PMOD1A_3): VCC (+5V if available, or +3.3V)
Pin 4 (PMOD1A_4): GND
```

### PMOD2A - NES Controller Port
```
Pin 1 (PMOD2A_1): NES CLOCK (from NES console)
Pin 2 (PMOD2A_2): NES LATCH (from NES console)
Pin 3 (PMOD2A_3): NES DATA (to NES console)
Pin 4 (PMOD2A_4): GND
Pin 7 (PMOD2A_7): VCC (+5V from NES console)
Pin 8 (PMOD2A_8): VCC enable (optional output)
```

## NES Controller Port Pinout

When looking at the NES console controller port (female 7-pin connector):
```
     ___
   /     \
  | 1 2 3 |
   | 4 5 |
    |6 7|
     ---

Pin 1: GND (Ground)
Pin 2: CLOCK (to controller)
Pin 3: LATCH (to controller)
Pin 4: DATA (from controller) - Connect to PMOD2A_3
Pin 5: Not used
Pin 6: Not used
Pin 7: +5V (Power)
```

## LED Indicators

- **Red LED (LEDR_N)**: 
  - OFF: Keyboard connected successfully
  - ON: Waiting for keyboard connection

- **Green LED (LEDG_N)**:
  - ON: Any button is currently pressed
  - OFF: No buttons pressed

## Power Considerations

1. The iCEBreaker should be powered via its USB programming port
2. The NES console provides +5V for the controller
3. USB keyboards typically require +5V, but many work with +3.3V
4. Consider using a level shifter for USB signals if using +5V

## Safety Notes

- Do not hot-plug connections to the NES console
- Ensure proper grounding between all components
- Use appropriate voltage levels for USB (3.3V or 5V depending on PMOD)
- Test with a multimeter before connecting to NES console

## Troubleshooting

### Keyboard not detected
- Check USB D+ and D- connections
- Verify power to USB keyboard
- Check LED indicator (should turn from red to off)
- Try different keyboard

### NES not reading controller
- Verify NES console is powered on
- Check CLOCK, LATCH, and DATA connections
- Measure voltages on NES controller port
- Test with original NES controller to verify console works

### Random button presses
- Check for noise on signal lines
- Add pull-up resistors on DATA line if needed
- Verify proper grounding
