`default_nettype none
`timescale 1ns / 1ps

// uart_tx.v — Simple UART transmitter for iCE40UP5K
// 8N1 format (8 data bits, no parity, 1 stop bit)
//
// Parameters:
//   CLK_HZ   - input clock frequency in Hz (default 48MHz from SB_HFOSC)
//   BAUD     - desired baud rate (default 115200)
//
// Usage:
//   Assert tx_valid with tx_data for one clock cycle.
//   tx_busy goes high while a byte is being sent.
//   Tie tx_valid low when tx_busy is high (or use flow control).
module uart_tx #(
    parameter CLK_HZ = 48_000_000,
    parameter BAUD   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    // Data interface
    input  wire [7:0] tx_data,
    input  wire       tx_valid,   // pulse high for 1 clk to load a byte
    output reg        tx_busy,    // high while transmitting
    // Physical pin
    output reg        tx_pin      // UART TX line (idle = 1)
);

    // Baud rate divider: rounds to nearest integer
    localparam integer CLK_DIV = (CLK_HZ + BAUD/2) / BAUD;

    // Internal state
    reg [$clog2(CLK_DIV)-1:0] clk_cnt;
    reg [9:0] shift_reg;   // {stop, data[7:0], start} - 10 bits for 8N1
    reg [3:0] bit_cnt;     // counts 0..9 (10 bits total)

    always @(posedge clk) begin
        if (rst) begin
            tx_pin    <= 1'b1;
            tx_busy   <= 1'b0;
            clk_cnt   <= 0;
            bit_cnt   <= 0;
            shift_reg <= 10'h3FF;
        end else begin
            if (!tx_busy) begin
                tx_pin <= 1'b1;
                if (tx_valid) begin
                    // Load: start bit (0) + 8 data bits + stop bit (1)
                    shift_reg <= {1'b1, tx_data, 1'b0};
                    bit_cnt   <= 0;
                    clk_cnt   <= 0;
                    tx_busy   <= 1'b1;
                end
            end else begin
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    tx_pin  <= shift_reg[0];
                    shift_reg <= {1'b1, shift_reg[9:1]};  // shift right
                    if (bit_cnt == 9) begin
                        tx_busy <= 1'b0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end

endmodule

`default_nettype wire