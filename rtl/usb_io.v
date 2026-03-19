`default_nettype none
`timescale 1ns / 1ps

// USB I/O: Tri-state I/O buffer for a single USB data pin (D+ or D-)
// Instantiate once per pin in top.v
//
// PIN_TYPE[5:3] = 3'b010  direct output, tri-statable via OUTPUT_ENABLE
// PIN_TYPE[2:0] = 3'b001  simple/direct input
// PULLUP = 0              external 15k pull-downs handle bus idle state
module usb_io (
    input  wire pin_o,   // data to drive onto pad (from core usb_dp_o / usb_dm_o)
    output wire pin_i,   // data read from pad (to core usb_dp_i / usb_dm_i)
    input  wire oe,      // output enable (from core usb_dp_oe / usb_dm_oe)
    inout  wire pad      // physical pad connection (to USB D+ or D- pin on connector)
);

    //  SB_IO: iCE40-specific I/O primitive for tri-state I/O buffers
    //  Configure for direct output when OE is high, and direct input when OE is low
    SB_IO #(
        .PIN_TYPE      (6'b101001), // 3 bits for output mode, 3 bits for input mode (Output Pin Function table)
        .PULLUP        (1'b0)       // no internal pull-up, external 15k pull-downs handle idle state
    ) sb_io_inst (
        .PACKAGE_PIN   (pad),   // physical pad connection
        .OUTPUT_ENABLE (oe),    // control signal to enable output driver
        .D_OUT_0       (pin_o), // data to drive onto pad
        .D_IN_0        (pin_i)  // data read from pad
    );

endmodule

`default_nettype wire