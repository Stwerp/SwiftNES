// NES Controller Interface
// Implements the serial shift register protocol used by NES controllers
// The NES reads the controller by pulsing LATCH high, then clocking out 8 bits

module nes_controller_interface (
    input wire clk,           // System clock
    input wire rst_n,         // Active-low reset
    
    // Button inputs (from keyboard mapper)
    input wire btn_a,
    input wire btn_b,
    input wire btn_select,
    input wire btn_start,
    input wire btn_up,
    input wire btn_down,
    input wire btn_left,
    input wire btn_right,
    
    // NES controller port signals
    input wire nes_clk,       // Clock from NES (normally ~1MHz pulses)
    input wire nes_latch,     // Latch from NES
    output reg nes_data       // Serial data to NES
);

    // NES controller button order (shifted out MSB first):
    // Bit 0: A
    // Bit 1: B
    // Bit 2: Select
    // Bit 3: Start
    // Bit 4: Up
    // Bit 5: Down
    // Bit 6: Left
    // Bit 7: Right
    
    reg [7:0] button_state;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;
    
    // Synchronize NES signals to our clock domain
    reg nes_clk_sync1, nes_clk_sync2, nes_clk_prev;
    reg nes_latch_sync1, nes_latch_sync2, nes_latch_prev;
    
    wire nes_clk_posedge;
    wire nes_latch_posedge;
    
    assign nes_clk_posedge = nes_clk_sync2 && !nes_clk_prev;
    assign nes_latch_posedge = nes_latch_sync2 && !nes_latch_prev;
    
    // Synchronizer and edge detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nes_clk_sync1 <= 0;
            nes_clk_sync2 <= 0;
            nes_clk_prev <= 0;
            nes_latch_sync1 <= 0;
            nes_latch_sync2 <= 0;
            nes_latch_prev <= 0;
        end else begin
            // Two-stage synchronizer
            nes_clk_sync1 <= nes_clk;
            nes_clk_sync2 <= nes_clk_sync1;
            nes_clk_prev <= nes_clk_sync2;
            
            nes_latch_sync1 <= nes_latch;
            nes_latch_sync2 <= nes_latch_sync1;
            nes_latch_prev <= nes_latch_sync2;
        end
    end
    
    // Combine button inputs into state byte
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_state <= 8'h00;
        end else begin
            // Pack buttons into byte (NES expects 0 for pressed, 1 for not pressed)
            // We invert our active-high buttons
            button_state <= {~btn_right, ~btn_left, ~btn_down, ~btn_up, 
                           ~btn_start, ~btn_select, ~btn_b, ~btn_a};
        end
    end
    
    // Shift register logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'hFF;
            bit_count <= 0;
            nes_data <= 1;
        end else begin
            // Latch signal loads current button state
            if (nes_latch_posedge) begin
                shift_reg <= button_state;
                bit_count <= 0;
                nes_data <= button_state[0];  // Output first bit immediately
            end 
            // Clock signal shifts out next bit
            else if (nes_clk_posedge && bit_count < 8) begin
                bit_count <= bit_count + 1;
                shift_reg <= {1'b1, shift_reg[7:1]};  // Shift right, fill with 1
                nes_data <= shift_reg[1];  // Output next bit
            end
            // After 8 bits, output high (no button pressed)
            else if (bit_count >= 8) begin
                nes_data <= 1;
            end
        end
    end

endmodule
