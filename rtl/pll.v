`default_nettype none
`timescale 1ns / 1ps

// PLL: Phase Locked Loop
// 12MHz crystal input -> 96 MHz output
// Parameters calculated with: icepll -i 12 -o 96
module pll (
    input wire clk_in,   // 12 MHz from iCEbreaker on-board crystal
    output wire clk_out, // 96 MHz to rest of design
    output wire locked   // asserteed when PLL has aquired lock
);

    // PLL instance
    SB_PLL40_PAD #(
        .FEEDBACK_PATH ("SIMPLE"),
        .DIVR          (4'b0000), // DIVR = 0
        .DIVF          (7'b0111111), // DIVF = 63
        .DIVQ          (3'b011), // DIVQ = 3
        .FILTER_RANGE  (3'b001) // FILTER_RANGE = 1
    ) pll_inst (
        .PACKAGEPIN    (clk_in),
        .PLLOUTCORE  (clk_out),
        .LOCK          (locked),
        .RESETB        (1'b1) // PLL reset is active low, tie to 1 to keep it enabled
        .BYPASS        (1'b0) // Disable bypass, use PLL output
    );

endmodule

`default_nettype wire