# USB HID Implementation Notes

## Current Implementation Status

The USB HID host module (`usb_hid_host.v`) currently contains a **simplified placeholder** implementation. This is intentional to provide a framework that can be extended with a full USB protocol stack.

## What's Implemented

1. **Basic State Machine**:
   - Reset detection
   - Device connection detection (via D+ pull-up)
   - Enumeration placeholder
   - Polling loop structure

2. **Interface Signals**:
   - USB D+/D- bidirectional pins with tristate control
   - Key code output (USB HID scancode)
   - Key valid pulse
   - Key press/release indication
   - Connection status

3. **Key Report Handling**:
   - Support for up to 6 simultaneous key presses (standard HID keyboard report)
   - Key press and release detection
   - Previous state tracking

## What's NOT Implemented (Future Work)

The following USB protocol features need to be added for a production-ready implementation:

### 1. USB Physical Layer (PHY)
- **NRZI encoding/decoding**: USB uses NRZI (Non-Return-to-Zero Inverted) encoding
- **Bit stuffing**: Insert/remove stuffing bits for long sequences of 1s
- **Sync pattern**: Detect and generate sync patterns
- **EOP detection**: End-of-packet detection and generation

### 2. USB Packet Layer
- **PID (Packet ID)**: Token, data, handshake, and special PIDs
- **CRC**: CRC5 for token packets, CRC16 for data packets
- **Token packets**: SETUP, IN, OUT
- **Data packets**: DATA0, DATA1 with toggling
- **Handshake packets**: ACK, NAK, STALL

### 3. USB Transaction Layer
- **Control transfers**: For enumeration
- **Interrupt transfers**: For HID keyboard reports
- **Retry logic**: Handle NAKs and retransmissions
- **Timeout handling**: Detect and recover from timeouts

### 4. USB Enumeration
Full enumeration sequence:
```
1. Reset device (drive D+/D- low for >10ms)
2. Get Device Descriptor (8 bytes)
3. Reset device again
4. Set Address
5. Get Device Descriptor (full)
6. Get Configuration Descriptor
7. Get HID Report Descriptor
8. Set Configuration
9. Set Idle (optional)
10. Set Protocol (boot protocol for keyboards)
```

### 5. HID Boot Protocol
- **HID Report Format**: Parse 8-byte keyboard reports
  ```
  Byte 0: Modifier keys (Ctrl, Shift, Alt, GUI)
  Byte 1: Reserved (always 0)
  Byte 2-7: Key codes (up to 6 simultaneous keys)
  ```
- **Polling interval**: Typically 8ms for keyboards
- **Report parsing**: Extract individual key presses

## Integration Options

To make this design fully functional, consider these approaches:

### Option 1: Implement USB Stack in Verilog
- Most control over timing and resources
- Significant development effort
- Good learning opportunity
- Reference: [USB-FPGA implementations](https://github.com/osresearch/up5k-demos)

### Option 2: Use Existing USB Core
- **TinyUSB**: Open-source USB stack
- **USBFS IP cores**: Various open-source cores available
- Faster development
- May require licensing considerations

### Option 3: Use Microcontroller Bridge
- Add a small MCU (e.g., STM32, RP2040) to handle USB
- MCU communicates with FPGA via SPI/UART
- Simpler FPGA design
- Additional hardware cost

### Option 4: PS/2 Keyboard Instead
- Much simpler protocol than USB
- PS/2 to USB adapters available
- Fewer keyboards support PS/2 today
- Easier to implement in pure Verilog

## Recommended Approach

For a working prototype, **Option 3** (microcontroller bridge) is recommended:

1. Use an MCU with USB host support (e.g., MAX3421E-based board)
2. MCU handles all USB enumeration and HID protocol
3. MCU sends simple key codes to FPGA via SPI/UART
4. FPGA focuses on NES protocol implementation

Example MCU code flow:
```cpp
void loop() {
    if (keyboard.available()) {
        uint8_t key = keyboard.read();
        bool pressed = keyboard.isPressed(key);
        
        // Send to FPGA: [key_code, pressed_flag]
        SPI.transfer(key);
        SPI.transfer(pressed ? 0x01 : 0x00);
    }
}
```

## Testing Without USB

For development and testing without a full USB implementation:

1. **Simulation**: Use testbenches to inject key codes directly
2. **Serial Input**: Temporarily replace USB module with UART input
3. **Hardcoded Keys**: For initial NES protocol testing, hardcode button states

## References

- [USB 2.0 Specification](https://www.usb.org/document-library/usb-20-specification)
- [USB HID Specification](https://www.usb.org/hid)
- [USB in a NutShell](https://www.beyondlogic.org/usbnutshell/usb1.shtml)
- [TinyUSB Stack](https://github.com/hathach/tinyusb)
- [MAX3421E USB Host Controller](https://www.maximintegrated.com/en/products/interface/controllers-expanders/MAX3421E.html)
