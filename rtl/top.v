`default_nettype none
`timescale 1ns / 1ps

// iCEbreaker top-level for usb_hid_host
// Supports both low-speed (1.5Mbps) and full-speed (12Mbps) USB HID devices.
// Runtime speed detection handled by BE instructions in UKP microcode.
//
// Clock domains:
//     clk_12 - 12 MHz from on-board crystal, used as PLL reference
//     clk_96 - 96 MHz from PLL, used for USB timing and core logic
module top (
    input wire clk_12,

    inout wire usb_dp,
    inout wire usb_dm,

    output wire [1:0] typ,
    output wire       full_report,
    output wire       connerr,
    output wire       busy,

    output wire [1:0] typ,
    output wire       full_report,
    output wire       connerr,
    output wire       busy,

    output wire [7:0] key_modifiers,
    output wire [7:0] key_0,
    output wire [7:0] key_1,
    output wire [7:0] key_2,
    output wire [7:0] key_3,

    output wire [2:0]        mouse_btn,
    output wire signed [7:0] mouse_dx,
    output wire signed [7:0] mouse_dy,

    output wire game_l, game_r, game_u, game_d,
    output wire game_a, game_b, game_x, game_y,
    output wire game_sel, game_sta,

    output wire [63:0] dbg_hid_report,
    output wire [63:0] dbg_hid_regs
);

    // PLL
    wire clk_96;
    wire pll_locked;

    // USB physical layer
    wire usb_dp_i, usb_dp_o;
    wire usb_dm_i, usb_dm_o;
    wire usb_oe;

    // ROM interface
    wire [9:0] rom_addr;
    wire [3:0] rom_dout;
    wire       rom_en;

    // Reset
    wire reset;
    assign reset = ~pll_locked;

    // -------------------------------------------------------------------------
    // PLL: 12 MHz -> 96 MHz
    // -------------------------------------------------------------------------
    pll pll_inst (
        .clk_in  (clk_12),
        .clk_out (clk_96),
        .locked  (pll_locked)
    );

    // -------------------------------------------------------------------------
    // USB tristate I/O buffers
    // -------------------------------------------------------------------------
    usb_io dp_io (
        .pad   (usb_dp),
        .pin_o (usb_dp_o),
        .pin_i (usb_dp_i),
        .oe    (usb_oe)
    );

    usb_io dm_io (
        .pad   (usb_dm),
        .pin_o (usb_dm_o),
        .pin_i (usb_dm_i),
        .oe    (usb_oe)
    );

    // -------------------------------------------------------------------------
    // UKP microcode ROM (1024 x 4-bit, mapped to one iCE40 EBR block)
    // -------------------------------------------------------------------------
    usb_hid_host_rom rom_inst (
        .clk  (clk_96),
        .addr (rom_addr),
        .en   (rom_en),
        .dout (rom_dout)
    );

    // -------------------------------------------------------------------------
    // USB HID host core
    // FULL_SPEED=1 enables runtime low/full speed detection via BE instruction.
    // reset held high until PLL locks to ensure clean startup.
    // -------------------------------------------------------------------------
    usb_hid_host #(
        .FULL_SPEED (1)
    ) core_inst (
        .clk           (clk_96),
        .reset         (reset),
        .cs            (1'b1),

        .usb_dp_i      (usb_dp_i),
        .usb_dp_o      (usb_dp_o),
        .usb_dm_i      (usb_dm_i),
        .usb_dm_o      (usb_dm_o),
        .usb_oe        (usb_oe),

        .typ           (typ),
        .full_report   (full_report),
        .connerr       (connerr),
        .busy          (busy),

        .key_modifiers (key_modifiers),
        .key_0         (key_0),
        .key_1         (key_1),
        .key_2         (key_2),
        .key_3         (key_3),

        .mouse_btn     (mouse_btn),
        .mouse_dx      (mouse_dx),
        .mouse_dy      (mouse_dy),

        .game_l        (game_l),
        .game_r        (game_r),
        .game_u        (game_u),
        .game_d        (game_d),
        .game_a        (game_a),
        .game_b        (game_b),
        .game_x        (game_x),
        .game_y        (game_y),
        .game_sel      (game_sel),
        .game_sta      (game_sta),

        .dbg_hid_report (dbg_hid_report),
        .dbg_hid_regs   (dbg_hid_regs),

        .rom_addr      (rom_addr),
        .rom_dout      (rom_dout),
        .rom_en        (rom_en)
    );

endmodule

`default_nettype wire