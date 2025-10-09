// Top-level module for PS/2 Keyboard to NES Controller adapter
// Alternative to USB version - simpler to implement
// Designed for Lattice iCEBreaker board (iCE40UP5K)

module top_ps2 (
    // iCEBreaker 12MHz clock
    input wire CLK,
    
    // Button for reset (BTN1 on iCEBreaker)
    input wire BTN_N,
    
    // LED outputs for status indication
    output wire LEDR_N,    // Red LED (active low)
    output wire LEDG_N,    // Green LED (active low)
    
    // PS/2 PMOD signals (PMOD1A or PMOD1B)
    input wire PMOD1A_1,   // PS/2 Clock
    input wire PMOD1A_2,   // PS/2 Data
    // PMOD1A_3: VCC (5V)
    // PMOD1A_4: GND
    
    // NES Controller port (PMOD2A or available pins)
    input wire PMOD2A_1,   // NES Clock
    input wire PMOD2A_2,   // NES Latch
    output wire PMOD2A_3,  // NES Data
    output wire PMOD2A_8   // VCC enable (optional)
);

    // Internal signals
    wire rst_n;
    wire clk_12mhz;
    
    // PS/2 keyboard signals
    wire [7:0] scan_code;
    wire scan_code_valid;
    wire key_release;
    
    // NES button signals
    wire btn_a, btn_b, btn_select, btn_start;
    wire btn_up, btn_down, btn_left, btn_right;
    
    // Clock and reset
    assign clk_12mhz = CLK;
    assign rst_n = BTN_N;  // Button is active-low
    
    // Status LEDs
    assign LEDR_N = 1'b1;  // Red LED off (PS/2 doesn't need enumeration)
    assign LEDG_N = ~(btn_a | btn_b | btn_start | btn_select | 
                      btn_up | btn_down | btn_left | btn_right);
                      // Green LED when any button pressed
    
    // VCC enable for NES port (always on)
    assign PMOD2A_8 = 1'b1;
    
    // PS/2 Keyboard Host module
    ps2_keyboard_host ps2_host (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .ps2_clk(PMOD1A_1),
        .ps2_data(PMOD1A_2),
        .scan_code(scan_code),
        .scan_code_valid(scan_code_valid),
        .key_release(key_release)
    );
    
    // PS/2 to NES mapper
    ps2_to_nes mapper (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .scan_code(scan_code),
        .scan_code_valid(scan_code_valid),
        .key_release(key_release),
        .btn_a(btn_a),
        .btn_b(btn_b),
        .btn_select(btn_select),
        .btn_start(btn_start),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right)
    );
    
    // NES controller interface
    nes_controller_interface nes_ctrl (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .btn_a(btn_a),
        .btn_b(btn_b),
        .btn_select(btn_select),
        .btn_start(btn_start),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .nes_clk(PMOD2A_1),
        .nes_latch(PMOD2A_2),
        .nes_data(PMOD2A_3)
    );

endmodule
