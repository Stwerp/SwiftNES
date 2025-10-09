// PS/2 Keyboard Interface (Alternative to USB)
// Simpler protocol, easier to implement in FPGA
// Note: Requires PS/2 keyboard or USB-to-PS/2 adapter

module ps2_keyboard_host (
    input wire clk,           // System clock
    input wire rst_n,         // Active-low reset
    
    // PS/2 signals
    input wire ps2_clk,       // PS/2 clock from keyboard
    input wire ps2_data,      // PS/2 data from keyboard
    
    // Output
    output reg [7:0] scan_code,    // PS/2 scan code
    output reg scan_code_valid,    // Scan code valid pulse
    output reg key_release         // 1 = release (break), 0 = make
);

    // PS/2 states
    localparam IDLE = 0;
    localparam RECEIVING = 1;
    localparam PARITY = 2;
    localparam STOP = 3;
    localparam PROCESS = 4;
    
    reg [2:0] state;
    reg [3:0] bit_count;
    reg [7:0] shift_reg;
    reg parity_bit;
    
    // Synchronize PS/2 clock
    reg ps2_clk_sync1, ps2_clk_sync2, ps2_clk_prev;
    wire ps2_clk_negedge;
    
    // PS/2 data synchronized
    reg ps2_data_sync;
    
    // Break code detection (0xF0 indicates next code is a key release)
    reg break_code_detected;
    
    assign ps2_clk_negedge = !ps2_clk_sync2 && ps2_clk_prev;
    
    // Synchronizers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync1 <= 1;
            ps2_clk_sync2 <= 1;
            ps2_clk_prev <= 1;
            ps2_data_sync <= 1;
        end else begin
            ps2_clk_sync1 <= ps2_clk;
            ps2_clk_sync2 <= ps2_clk_sync1;
            ps2_clk_prev <= ps2_clk_sync2;
            ps2_data_sync <= ps2_data;
        end
    end
    
    // PS/2 receiver state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_count <= 0;
            shift_reg <= 0;
            parity_bit <= 0;
            scan_code <= 0;
            scan_code_valid <= 0;
            key_release <= 0;
            break_code_detected <= 0;
        end else begin
            scan_code_valid <= 0;  // Default: no new scan code
            
            if (ps2_clk_negedge) begin
                case (state)
                    IDLE: begin
                        // Start bit should be 0
                        if (ps2_data_sync == 0) begin
                            state <= RECEIVING;
                            bit_count <= 0;
                            shift_reg <= 0;
                            parity_bit <= 0;
                        end
                    end
                    
                    RECEIVING: begin
                        // Receive 8 data bits (LSB first)
                        shift_reg <= {ps2_data_sync, shift_reg[7:1]};
                        parity_bit <= parity_bit ^ ps2_data_sync;
                        bit_count <= bit_count + 1;
                        
                        if (bit_count == 7) begin
                            state <= PARITY;
                        end
                    end
                    
                    PARITY: begin
                        // Check parity bit (odd parity)
                        if ((parity_bit ^ ps2_data_sync) == 1) begin
                            state <= STOP;
                        end else begin
                            // Parity error - ignore this byte
                            state <= IDLE;
                        end
                    end
                    
                    STOP: begin
                        // Stop bit should be 1
                        if (ps2_data_sync == 1) begin
                            state <= PROCESS;
                        end else begin
                            state <= IDLE;
                        end
                    end
                    
                    PROCESS: begin
                        // Process received scan code
                        if (shift_reg == 8'hF0) begin
                            // Break code prefix
                            break_code_detected <= 1;
                        end else if (shift_reg == 8'hE0) begin
                            // Extended key prefix - ignore for now
                        end else begin
                            // Normal scan code
                            scan_code <= shift_reg;
                            scan_code_valid <= 1;
                            key_release <= break_code_detected;
                            break_code_detected <= 0;
                        end
                        state <= IDLE;
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule
