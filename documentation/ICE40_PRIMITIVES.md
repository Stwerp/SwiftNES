# iCE40 Primitives Reference
 
This document describes the three iCE40 hardware primitives used in this
port of `usb_hid_host` to the iCEbreaker board. All information is sourced
from the *iCE Technology Library* (Lattice Semiconductor, January 2017).
 
---

## SB_PLL40_PAD
 
**Used in:** `rtl/pll.v`

### Purpose
 
Generates the 96 MHz core clock from the iCEbreaker's 12 MHz on-board
crystal oscillator.

### When to use SB_PLL40_PAD vs SB_PLL40_CORE
 
The datasheet states:
 
> The SB_PLL40_PAD primitive should be used when the source clock of the
> PLL is driven by an input pad that is located in the bottom IO bank
> (IO Bank 2) or the top IO bank (IO Bank 0), and the source clock is
> **not** required inside the FPGA.
 
The iCEbreaker's 12 MHz crystal connects directly to a dedicated PLL pad
pin (pin 35, IO Bank 2). Since the 12 MHz reference is not needed anywhere
in the fabric — only the 96 MHz output is — `SB_PLL40_PAD` is the correct
choice. Using `SB_PLL40_CORE` would route the 12 MHz signal through general
fabric routing before feeding it into the PLL, adding jitter unnecessarily.
 
### Ports used
 
| Port | Direction | Description |
|------|-----------|-------------|
| `PACKAGEPIN` | Input | PLL reference clock — connects directly to the crystal pad |
| `PLLOUTCORE` | Output | Generated clock driving regular FPGA routing fabric |
| `LOCK` | Output | High when PLL output is stable and locked to reference |
| `RESETB` | Input | Active-low async reset — tied high (not used) |
| `BYPASS` | Input | Routes `PACKAGEPIN` straight to output when high — tied low |
 
`PLLOUTCORE` is used rather than `PLLOUTGLOBAL`. The datasheet notes both
outputs produce the same frequency; `PLLOUTGLOBAL` drives a dedicated global
clock network. Either works at 96 MHz on an UP5K — `PLLOUTCORE` is
sufficient and avoids consuming a global clock resource unnecessarily.

### Parameters
 
| Parameter | Value | Description |
|-----------|-------|-------------|
| `FEEDBACK_PATH` | `"SIMPLE"` | Feedback is internal to the PLL, directly from VCO — no external path or phase adjustment needed |
| `DIVR` | `4'b0000` (0) | Reference clock divider |
| `DIVF` | `7'b0111111` (63) | Feedback divider |
| `DIVQ` | `3'b011` (3) | VCO output divider |
| `FILTER_RANGE` | `3'b001` (1) | PLL loop filter bandwidth setting |
 
### Frequency calculation
 
The output frequency formula is:
 
```
F_out = (F_in * (DIVF + 1)) / ((DIVR + 1) * 2^DIVQ)
F_out = (12 MHz * 64) / (1 * 8) = 96 MHz
```
 
Parameters were verified using `icepll -i 12 -o 96`.
 
### FEEDBACK_PATH options
 
The datasheet defines four `FEEDBACK_PATH` modes:
 
| Value | Description |
|-------|-------------|
| `SIMPLE` | Feedback internal, directly from VCO |
| `DELAY` | Feedback internal, through Fine Delay Adjust Block |
| `PHASE_AND_DELAY` | Feedback internal, through Phase Shifter and Fine Delay Adjust Block |
| `EXTERNAL` | Feedback path external to PLL via `EXTFEEDBACK` pin |
 
`SIMPLE` is the correct mode for a straightforward frequency multiplication
with no phase alignment requirements.
 
---
 
## SB_IO
 
**Used in:** `rtl/usb_io.v`
 
### Purpose
 
Implements tristatable bidirectional I/O for the USB D+ and D- pins.
One instance is used per pin.
 
### Why explicit instantiation is required
 
Yosys cannot reliably infer tristate I/O from behavioral Verilog (`assign
pad = oe ? out : 1'bz`) for iCE40 targets. Without explicit `SB_IO`
instantiation the pin may be synthesized as a permanent output, which
would drive the USB bus at all times and conflict electrically with
connected devices.
 
### Ports used
 
| Port | Direction | Description |
|------|-----------|-------------|
| `PACKAGE_PIN` | Inout | Physical FPGA pin — connects to USB D+ or D- |
| `OUTPUT_ENABLE` | Input | High = drive pin from `D_OUT_0`; Low = hi-Z |
| `D_OUT_0` | Input | Data to drive onto pin (from core `usb_dp_o` / `usb_dm_o`) |
| `D_IN_0` | Output | Data sampled from pin (to core `usb_dp_i` / `usb_dm_i`) |
 
The DDR ports `D_OUT_1` and `D_IN_1` and the clock ports are left
unconnected. The datasheet notes the iCEcube2 software assigns logic `0`
to all unconnected input ports except `CLOCK_ENABLE`, which is safe for
the non-DDR configuration used here.
 
### PIN_TYPE
 
`PIN_TYPE` is a 6-bit parameter composed of two independent fields:
 
```
PIN_TYPE[5:2] = output function
PIN_TYPE[1:0] = input function
defparam my_io.PIN_TYPE = 6'b{Output Pin Function, Input Pin Function};
```
 
**Output function — `PIN_TYPE[5:2]`**
 
| # | Mnemonic | PIN_TYPE[5:2] | Description |
|---|----------|---------------|-------------|
| 1 | `PIN_NO_OUTPUT` | `0000` | Output disabled |
| 2 | `PIN_OUTPUT` | `0110` | Simple output, no enable |
| 3 | `PIN_OUTPUT_TRISTATE` | `1010` | Output tristatable via `OUTPUT_ENABLE` |
| 4 | `PIN_OUTPUT_ENABLE_REGISTERED` | `1110` | Tristatable, registered enable |
| 5 | `PIN_OUTPUT_REGISTERED` | `0101` | Registered output, no enable |
 
`PIN_OUTPUT_TRISTATE` (row 3, `1010`) is used — the output is driven
directly (non-registered) from `D_OUT_0` and tristated by `OUTPUT_ENABLE`.
Non-registered is required because the core manages USB bit timing
internally; adding a register here would introduce one cycle of latency
and corrupt bit timing.
 
**Input function — `PIN_TYPE[1:0]`**
 
| # | Mnemonic | PIN_TYPE[1:0] | Description |
|---|----------|---------------|-------------|
| 1 | `PIN_INPUT` | `01` | Simple/direct input via `D_IN_0` |
| 2 | `PIN_INPUT_LATCH` | `11` | Latched input |
| 3 | `PIN_INPUT_REGISTERED` | `00` | Registered input |
| 5 | `PIN_INPUT_DDR` | `00` | DDR input |
 
`PIN_INPUT` (`01`) is used — direct, non-registered input. Same reasoning
as the output side: the core handles its own sampling; a register here
would add unwanted latency.
 
**Combined value:**
 
```
PIN_TYPE = 6'b{1010, 01} = 6'b101001
```
 
### PULLUP parameter
 
`PULLUP` is set to `1'b0` (disabled). The USB specification requires
15 kΩ pull-down resistors on D+ and D- for host-mode operation. These
are provided externally on the USB frontend board. Enabling the iCE40
internal weak pull-up would fight the external pull-downs and corrupt
bus idle state detection.
 
---
 
## EBR — Embedded Block RAM
 
**Used in:** `rtl/usb_hid_host_rom.v` (via Yosys inference)
 
### Purpose
 
Stores the 1024 × 4-bit UKP microcode ROM. Inferred by Yosys from a
behavioral `reg` array using the `ram_style` synthesis attribute.
 
### iCE40 EBR architecture
 
Each iCE40 EBR block is 4096 bits with a fixed 16-bit data width,
physically arranged as 256 × 16. The block supports four logical
configurations, all of which are 4096 bits total:
 
| Primitive | Depth | Width | Address bits | Data bits |
|-----------|-------|-------|-------------|-----------|
| `SB_RAM256x16` | 256 | 16 | 8 | 16 |
| `SB_RAM512x8` | 512 | 8 | 9 | 8 |
| `SB_RAM1024x4` | 1024 | 4 | 10 | 4 |
| `SB_RAM2048x2` | 2048 | 2 | 11 | 2 |
 
The ROM in this design is 1024 × 4-bit — an exact match for
`SB_RAM1024x4`. Yosys maps the inferred array to exactly one EBR block.
 
The UP5K has 30 EBR blocks available. This design consumes one.
 
### Why inference rather than direct instantiation
 
`SB_RAM1024x4` can be directly instantiated, but its initial content
must be provided as sixteen 256-bit `INIT_x` parameters encoded in hex.
These would need to be recalculated every time the microcode in
`rom/ukp.s` changes.
 
Using Yosys inference with `$readmemh` means the `.mem` file drives ROM
content automatically at synthesis time — no manual encoding required.
 
### Forcing EBR inference with ram_style
 
Without guidance, Yosys may choose to implement a `reg` array in LUT RAM
(Distributed RAM) rather than EBR. On the UP5K, which has only 5280 LUTs,
a 1024 × 4-bit array in LUT RAM would consume a significant portion of
the device.
 
The synthesis attribute:
 
```verilog
(* ram_style = "block" *)
reg [3:0] mem [0:1023];
```
 
instructs Yosys to use EBR. The synthesis log should report:
 
```
Mapping to iCE40 rams
```
 
and nextpnr should show EBR utilization increase by 1. If LUT count
increases by ~200 instead, the attribute did not take effect.
 
### Read timing
 
The ROM uses synchronous read with active-high enable:
 
```verilog
always @(posedge clk) begin
    if (en)
        dout <= mem[addr];
end
```
 
The `ukp` state machine in `usb_hid_host.v` presents `pc_next` to
`rom_addr` one cycle before it needs the result, then reads `rom_dout`
the following cycle. This matches standard synchronous EBR read behavior
and must not be changed to asynchronous read.
 
---
 
## Resource summary
 
| Primitive | Instance | Count |
|-----------|----------|-------|
| `SB_PLL40_PAD` | `pll_inst` in `pll.v` | 1 |
| `SB_IO` | `dp_io`, `dm_io` in `top.v` | 2 |
| EBR (`SB_RAM1024x4`) | inferred in `usb_hid_host_rom.v` | 1 |
 
---
 
## References
 
- *iCE Technology Library*, Lattice Semiconductor Corporation, January 2017
- `icepll` utility — PLL parameter calculator, part of IceStorm toolchain
- [Project IceStorm](https://clifford.at/icestorm/) — iCE40 bitstream documentation
- [iCEbreaker hardware repository](https://github.com/icebreaker-fpga/icebreaker)