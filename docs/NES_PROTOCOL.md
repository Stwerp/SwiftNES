# NES Controller Protocol

## Overview
The NES (Nintendo Entertainment System) controller uses a simple serial protocol to communicate with the console. Understanding this protocol is essential for emulating a controller.

## Hardware Interface
The NES controller port has 7 pins:
- **+5V**: Power supply
- **GND**: Ground
- **CLOCK**: Clock signal from console
- **LATCH**: Latch/strobe signal from console
- **DATA**: Serial data from controller to console
- **D3**: Not used in standard controllers
- **D4**: Not used in standard controllers

## Protocol Timing

The NES reads the controller state in the following sequence:

1. **Latch Phase**: Console pulses LATCH high for ~12μs
   - Controller latches current button states into an 8-bit shift register
   
2. **Clock Phase**: Console pulses CLOCK 8 times
   - On each rising edge of CLOCK, controller outputs the next bit
   - First bit is output immediately when LATCH goes low
   - Remaining 7 bits are output on subsequent CLOCK pulses

## Button Mapping

The 8 bits are transmitted in this order (bit 0 first):
```
Bit 0: A Button
Bit 1: B Button
Bit 2: SELECT Button
Bit 3: START Button
Bit 4: UP on D-Pad
Bit 5: DOWN on D-Pad
Bit 6: LEFT on D-Pad
Bit 7: RIGHT on D-Pad
```

## Data Format

- **0 (logic low)**: Button is PRESSED
- **1 (logic high)**: Button is NOT pressed

After the 8th bit, the DATA line should remain high until the next LATCH.

## Timing Specifications

- **Latch pulse width**: ~12μs
- **Clock frequency**: ~60 kHz (period ~16μs)
- **Reading interval**: Once per video frame (~16.7ms for NTSC, ~20ms for PAL)

## Implementation Notes

1. The controller must respond quickly to LATCH and CLOCK signals
2. Proper synchronization is crucial when crossing clock domains
3. The shift register should be loaded atomically on LATCH
4. All timing is driven by the console - the controller is passive

## References
- [NES Controller Wikipedia](https://en.wikipedia.org/wiki/NES_Controller)
- [NESdev Wiki - Standard Controller](https://www.nesdev.org/wiki/Standard_controller)
