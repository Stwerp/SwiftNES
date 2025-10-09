// PS/2 Keyboard to NES Controller Mapper
// Maps PS/2 scan codes to NES controller buttons

module ps2_to_nes (
    input wire clk,
    input wire rst_n,
    
    // PS/2 keyboard input
    input wire [7:0] scan_code,
    input wire scan_code_valid,
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

    // PS/2 Scan Codes (Set 2 - Make codes)
    localparam PS2_W      = 8'h1D;  // W - Up
    localparam PS2_A      = 8'h1C;  // A - Left
    localparam PS2_S      = 8'h1B;  // S - Down
    localparam PS2_D      = 8'h23;  // D - Right
    localparam PS2_J      = 8'h3B;  // J - B button
    localparam PS2_K      = 8'h42;  // K - A button
    localparam PS2_ENTER  = 8'h5A;  // Enter - Start
    localparam PS2_RSHIFT = 8'h59;  // Right Shift - Select
    localparam PS2_SPACE  = 8'h29;  // Space - also A button
    
    // Arrow keys
    // Note: Arrow keys send extended codes (E0 prefix), which would need
    // special handling. For simplicity, using WASD is recommended.
    
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
        end else if (scan_code_valid) begin
            case (scan_code)
                // Direction keys - WASD
                PS2_W: btn_up <= !key_release;
                PS2_S: btn_down <= !key_release;
                PS2_A: btn_left <= !key_release;
                PS2_D: btn_right <= !key_release;
                
                // Action buttons
                PS2_K, PS2_SPACE: btn_a <= !key_release;
                PS2_J: btn_b <= !key_release;
                
                // System buttons
                PS2_ENTER: btn_start <= !key_release;
                PS2_RSHIFT: btn_select <= !key_release;
                
                default: begin
                    // Do nothing for unmapped keys
                end
            endcase
        end
    end

endmodule
