#!/usr/bin/env python3
"""
decode_hid.py — reads K: lines from the iCEbreaker UART stream and
decodes them into human-readable key events.

Usage:
    python3 decode_hid.py /dev/ttyUSB1

Format received:
    K:<mod> <k0> <k1> <k2> <k3>\n
    e.g.  K:02 04 00 00 00
          -> left-shift held, key_0=0x04 ('a' -> 'A')
"""

import sys
import serial

# USB HID Usage Table (page 0x07 — keyboard)
HID_USAGE = {
    0x00: '',        0x04: 'a',  0x05: 'b',  0x06: 'c',
    0x07: 'd',  0x08: 'e',  0x09: 'f',  0x0A: 'g',
    0x0B: 'h',  0x0C: 'i',  0x0D: 'j',  0x0E: 'k',
    0x0F: 'l',  0x10: 'm',  0x11: 'n',  0x12: 'o',
    0x13: 'p',  0x14: 'q',  0x15: 'r',  0x16: 's',
    0x17: 't',  0x18: 'u',  0x19: 'v',  0x1A: 'w',
    0x1B: 'x',  0x1C: 'y',  0x1D: 'z',
    0x1E: '1',  0x1F: '2',  0x20: '3',  0x21: '4',
    0x22: '5',  0x23: '6',  0x24: '7',  0x25: '8',
    0x26: '9',  0x27: '0',
    0x28: 'ENTER',      0x29: 'ESC',    0x2A: 'BACKSPACE',
    0x2B: 'TAB',        0x2C: 'SPACE',  0x2D: '-',
    0x2E: '=',          0x2F: '[',      0x30: ']',
    0x31: '\\',         0x33: ';',      0x34: "'",
    0x35: '`',          0x36: ',',      0x37: '.',
    0x38: '/',          0x39: 'CAPS',
    0x3A: 'F1',  0x3B: 'F2',  0x3C: 'F3',  0x3D: 'F4',
    0x3E: 'F5',  0x3F: 'F6',  0x40: 'F7',  0x41: 'F8',
    0x42: 'F9',  0x43: 'F10', 0x44: 'F11', 0x45: 'F12',
    0x4F: 'RIGHT', 0x50: 'LEFT', 0x51: 'DOWN', 0x52: 'UP',
}

MODIFIERS = [
    (0x01, 'LCTRL'), (0x02, 'LSHIFT'), (0x04, 'LALT'),  (0x08, 'LMETA'),
    (0x10, 'RCTRL'), (0x20, 'RSHIFT'), (0x40, 'RALT'),  (0x80, 'RMETA'),
]

def decode_modifiers(mod):
    return '+'.join(name for bit, name in MODIFIERS if mod & bit) or '-'

def decode_key(code):
    if code == 0:
        return '(none)'
    name = HID_USAGE.get(code)
    if name:
        return repr(name)
    return f'0x{code:02X}'

def main():
    port = sys.argv[1] if len(sys.argv) > 1 else '/dev/ttyUSB1'
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200

    print(f"Opening {port} at {baud} baud  (Ctrl-C to quit)")
    print(f"{'RAW':<25}  {'MODIFIERS':<20}  KEYS")
    print('-' * 70)

    with serial.Serial(port, baud, timeout=1) as ser:
        while True:
            line = ser.readline().decode('ascii', errors='replace').strip()
            if not line.startswith('K:'):
                continue
            try:
                # K:MM KK KK KK KK
                parts = line[2:].split()
                mod   = int(parts[0], 16)
                keys  = [int(p, 16) for p in parts[1:5]]
            except (ValueError, IndexError):
                print(f"  [malformed] {line!r}")
                continue

            mods_str  = decode_modifiers(mod)
            keys_str  = '  '.join(decode_key(k) for k in keys if k != 0) or '(all released)'
            print(f"  {line:<25}  {mods_str:<20}  {keys_str}")

if __name__ == '__main__':
    main()