// Keyboard to NES Controller Mapper
// Maps USB HID keyboard scancodes to NES controller buttons

module keyboard_to_nes (
    input wire clk,
    input wire rst_n,
    
    // Keyboard input
    input wire [7:0] key_code,
    input wire key_valid,
    input wire key_release,
    
    // NES button outputs (active when pressed)
    output reg btn_a,
    output reg btn_b,
    output reg btn_select,
    output reg btn_start,
    output reg btn_up,
    output reg btn_down,
    output reg btn_left,
    output reg btn_right
);

    // USB HID Keyboard Scancodes (Page 0x07)
    localparam KEY_W      = 8'h1A;  // W - Up
    localparam KEY_A      = 8'h04;  // A - Left
    localparam KEY_S      = 8'h16;  // S - Down
    localparam KEY_D      = 8'h07;  // D - Right
    localparam KEY_J      = 8'h0D;  // J - B button
    localparam KEY_K      = 8'h0E;  // K - A button
    localparam KEY_ENTER  = 8'h28;  // Enter - Start
    localparam KEY_RSHIFT = 8'hE5;  // Right Shift - Select
    localparam KEY_SPACE  = 8'h2C;  // Space - also A button
    
    // Arrow keys (alternative)
    localparam KEY_UP     = 8'h52;
    localparam KEY_DOWN   = 8'h51;
    localparam KEY_LEFT   = 8'h50;
    localparam KEY_RIGHT  = 8'h4F;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_a <= 0;
            btn_b <= 0;
            btn_select <= 0;
            btn_start <= 0;
            btn_up <= 0;
            btn_down <= 0;
            btn_left <= 0;
            btn_right <= 0;
        end else if (key_valid) begin
            case (key_code)
                // Direction keys - WASD
                KEY_W: btn_up <= !key_release;
                KEY_S: btn_down <= !key_release;
                KEY_A: btn_left <= !key_release;
                KEY_D: btn_right <= !key_release;
                
                // Direction keys - Arrow keys
                KEY_UP: btn_up <= !key_release;
                KEY_DOWN: btn_down <= !key_release;
                KEY_LEFT: btn_left <= !key_release;
                KEY_RIGHT: btn_right <= !key_release;
                
                // Action buttons
                KEY_K, KEY_SPACE: btn_a <= !key_release;
                KEY_J: btn_b <= !key_release;
                
                // System buttons
                KEY_ENTER: btn_start <= !key_release;
                KEY_RSHIFT: btn_select <= !key_release;
                
                default: begin
                    // Do nothing for unmapped keys
                end
            endcase
        end
    end

endmodule
