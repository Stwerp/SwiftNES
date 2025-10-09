// Top-level module for USB Keyboard to NES Controller adapter
// Designed for Lattice iCEBreaker board (iCE40UP5K)

module top (
    // iCEBreaker 12MHz clock
    input wire CLK,
    
    // Button for reset (BTN1 on iCEBreaker)
    input wire BTN_N,
    
    // LED outputs for status indication
    output wire LEDR_N,    // Red LED (active low)
    output wire LEDG_N,    // Green LED (active low)
    
    // USB PMOD signals (PMOD1A or PMOD1B)
    inout wire PMOD1A_1,   // USB D+
    inout wire PMOD1A_2,   // USB D-
    // PMOD1A_3: VCC (5V)
    // PMOD1A_4: GND
    
    // NES Controller port (PMOD2A or available pins)
    input wire PMOD2A_1,   // NES Clock
    input wire PMOD2A_2,   // NES Latch
    output wire PMOD2A_3,  // NES Data
    // PMOD2A_4: GND
    // PMOD2A_7: VCC (5V)
    output wire PMOD2A_8   // VCC enable (optional)
);

    // Internal signals
    wire rst_n;
    wire clk_12mhz;
    
    // USB keyboard signals
    wire [7:0] key_code;
    wire key_valid;
    wire key_release;
    wire keyboard_connected;
    
    // NES button signals
    wire btn_a, btn_b, btn_select, btn_start;
    wire btn_up, btn_down, btn_left, btn_right;
    
    // Clock and reset
    assign clk_12mhz = CLK;
    assign rst_n = BTN_N;  // Button is active-low
    
    // Status LEDs
    assign LEDR_N = ~keyboard_connected;  // Red LED on when keyboard not connected
    assign LEDG_N = ~(keyboard_connected & (btn_a | btn_b | btn_start | btn_select | 
                                            btn_up | btn_down | btn_left | btn_right));
                                            // Green LED when keyboard connected and any button pressed
    
    // VCC enable for NES port (always on)
    assign PMOD2A_8 = 1'b1;
    
    // USB HID Host module
    usb_hid_host usb_host (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .usb_dp(PMOD1A_1),
        .usb_dm(PMOD1A_2),
        .key_code(key_code),
        .key_valid(key_valid),
        .key_release(key_release),
        .keyboard_connected(keyboard_connected)
    );
    
    // Keyboard to NES mapper
    keyboard_to_nes mapper (
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .key_code(key_code),
        .key_valid(key_valid),
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
