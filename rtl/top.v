`default_nettype none
`timescale 1ns / 1ps

// iCEbreaker top-level for usb_hid_host
// Supports both low-speed (1.5Mbps) and full-speed (12Mbps) USB HID devices.
// Runtime speed detection handled by BE instruction in UKP microcode.
//
// Clock domains:
//     clk_12 - 12 MHz from on-board crystal, used as PLL reference
//     clk_96 - 96 MHz from PLL, used for USB timing and core logic
//
// HID outputs are internal wires at this stage. Promote to ports and add
// PCF constraints when connecting to application logic.
module top (
    input  wire clk_12,

    // USB D+/D- (bidirectional)
    inout  wire usb_dp,
    inout  wire usb_dm,

    // Scope probes — mirrors of sampled USB signals
    output wire probe_dp,
    output wire probe_dm,

    // UART to host
    output wire uart_tx,
    input  wire uart_rx,    // not used here, but keeps PCF happy

    // Status LEDs
    output wire led_green,
    output wire led_red
);


    // -----------------------------------------------------------------------
    // PLL: 12 MHz -> 96 MHz
    // -----------------------------------------------------------------------
    wire clk_96;
    wire pll_locked;
    pll pll_inst (
        .clk_in  (clk_12),
        .clk_out (clk_96),
        .locked  (pll_locked)
    );

    // -----------------------------------------------------------------------
    // Reset — 4-stage synchroniser into clk_96 domain
    // -----------------------------------------------------------------------
    reg [3:0] reset_sr;
    always @(posedge clk_96)
        reset_sr <= {reset_sr[2:0], pll_locked};
    wire reset = ~reset_sr[3];

    // -----------------------------------------------------------------------
    // USB physical layer
    // -----------------------------------------------------------------------
    wire usb_dp_i, usb_dp_o;
    wire usb_dm_i, usb_dm_o;
    wire usb_oe;

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
    assign probe_dp = usb_dp_i;
    assign probe_dm = usb_dm_i;

    // -----------------------------------------------------------------------
    // UKP microcode ROM
    // -----------------------------------------------------------------------
    wire [9:0] rom_addr;
    wire [3:0] rom_dout;
    wire       rom_en;

    usb_hid_host_rom rom_inst (
        .clk  (clk_96),
        .addr (rom_addr),
        .en   (rom_en),
        .dout (rom_dout)
    );

    // -----------------------------------------------------------------------
    // USB HID host core
    // -----------------------------------------------------------------------
    wire [1:0]        typ;
    wire              full_report, connerr, busy;
    wire [7:0]        key_modifiers, key_0, key_1, key_2, key_3;
    wire [2:0]        mouse_btn;
    wire signed [7:0] mouse_dx, mouse_dy;
    wire              game_l, game_r, game_u, game_d;
    wire              game_a, game_b, game_x, game_y;
    wire              game_sel, game_sta;
    wire [63:0]       dbg_hid_report, dbg_hid_regs;

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
        .game_l        (game_l),  .game_r (game_r),
        .game_u        (game_u),  .game_d (game_d),
        .game_a        (game_a),  .game_b (game_b),
        .game_x        (game_x),  .game_y (game_y),
        .game_sel      (game_sel),.game_sta(game_sta),
        .dbg_hid_report(dbg_hid_report),
        .dbg_hid_regs  (dbg_hid_regs),
        .rom_addr      (rom_addr),
        .rom_dout      (rom_dout),
        .rom_en        (rom_en)
    );

    // -----------------------------------------------------------------------
    // UART reporter — keyboard events -> serial stream
    // -----------------------------------------------------------------------
    hid_uart_reporter #(
        .CLK_HZ (96_000_000),
        .BAUD   (115_200)
    ) reporter_inst (
        .clk          (clk_96),
        .rst          (reset),
        .key_modifiers(key_modifiers),
        .key_0        (key_0),
        .key_1        (key_1),
        .key_2        (key_2),
        .key_3        (key_3),
        .hid_busy     (busy),
        .uart_tx      (uart_tx)
    );

    // -----------------------------------------------------------------------
    // LED indicators
    //   green: heartbeat ~1.4 Hz at 96 MHz (bit 26 of 27-bit counter)
    //   red:   USB device connected (typ != 0)
    // -----------------------------------------------------------------------
    reg [26:0] hb;
    always @(posedge clk_96) hb <= hb + 1;
    assign led_green = hb[26] ^ rom_dout[0];
    assign led_red   = (typ != 2'b00);


endmodule

`default_nettype wire