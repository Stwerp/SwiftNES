`default_nettype none
`timescale 1ns / 1ps

// Watches usb_hid_host keyboard outputs and streams a
// formatted report over UART whenever the key state changes.
//
// Output format (one line per change, ASCII, 115200 8N1):
//   K: <mod> <k0> <k1> <k2> <k3>\n
//
// Each field is two uppercase hex digits, e.g.:
//   K:02 04 00 00 00\n   -> left-shift + 'a' (keycode 0x04)
//
// All on one clock domain (clk). Use the same clock as the HID core
// (clk_96) and set CLK_HZ=96_000_000, or use SB_HFOSC at 48 MHz.
//
// Back-pressure: the module queues one report in a small shift buffer.
// If a second change arrives before the first finishes sending, it is
// latched and will be sent immediately after.
module hid_uart_reporter #(
    parameter CLK_HZ = 96_000_000,
    parameter BAUD   = 115_200
) (
    input wire clk,
    input wire rst,

    // Device type from usb_hid_host
    // 0:none 1:keyboard 2:mouse 3:other
    input wire [1:0] typ,

    // Keyboard report inputs from usb_hid_host
    input wire [7:0] key_modifiers,
    input wire [7:0] key_0,
    input wire [7:0] key_1,
    input wire [7:0] key_2,
    input wire [7:0] key_3,

    // Mouse report inputs from usb_hid_host
    input wire [2:0]        mouse_btn,
    input wire signed [7:0] mouse_dx,
    input wire signed [7:0] mouse_dy,

    // Optional: pulse when a complete new HID report has arrived.
    // Tie to 1'b1 if you don't have this signal.
    input wire hid_busy,  // from core .busy port

    // UART TX pin
    output wire uart_tx
);

    // -------------------------------------------------------------------------
    // Change detection — capture on falling edge of busy (report complete)
    // -------------------------------------------------------------------------
    reg       busy_prev;
    reg [7:0] last_mod, last_k0, last_k1, last_k2, last_k3;
    reg [2:0] last_mbtn;
    reg [7:0] last_mdx, last_mdy;

    wire report_done = busy_prev & ~hid_busy;  // falling edge of busy

    always @(posedge clk)
        busy_prev <= hid_busy;

    wire keys_changed = (key_modifiers != last_mod) ||
                        (key_0 != last_k0) ||
                        (key_1 != last_k1) ||
                        (key_2 != last_k2) ||
                        (key_3 != last_k3);

    wire mouse_changed = (mouse_btn != last_mbtn) ||
                         (mouse_dx[7:0] != last_mdx) ||
                         (mouse_dy[7:0] != last_mdy);

    // Latch new report when it arrives and something changed
    reg       pending;
    reg       pending_is_mouse;
    reg [7:0] pend_mod, pend_k0, pend_k1, pend_k2, pend_k3;
    reg [2:0] pend_mbtn;
    reg [7:0] pend_mdx, pend_mdy;

    always @(posedge clk) begin
        if (rst) begin
            pending  <= 1'b0;
            pending_is_mouse <= 1'b0;
            last_mod <= 8'h00;
            last_k0  <= 8'h00;
            last_k1  <= 8'h00;
            last_k2  <= 8'h00;
            last_k3  <= 8'h00;
            last_mbtn <= 3'b000;
            last_mdx  <= 8'h00;
            last_mdy  <= 8'h00;
        end else if (report_done) begin
            if (typ == 2'd1 && keys_changed) begin
                pending  <= 1'b1;
                pending_is_mouse <= 1'b0;
                pend_mod <= key_modifiers;
                pend_k0  <= key_0;
                pend_k1  <= key_1;
                pend_k2  <= key_2;
                pend_k3  <= key_3;
                last_mod <= key_modifiers;
                last_k0  <= key_0;
                last_k1  <= key_1;
                last_k2  <= key_2;
                last_k3  <= key_3;
            end else if (typ == 2'd2 && mouse_changed) begin
                pending  <= 1'b1;
                pending_is_mouse <= 1'b1;
                pend_mbtn <= mouse_btn;
                pend_mdx  <= mouse_dx[7:0];
                pend_mdy  <= mouse_dy[7:0];
                last_mbtn <= mouse_btn;
                last_mdx  <= mouse_dx[7:0];
                last_mdy  <= mouse_dy[7:0];
            end
        end else if (sending_start) begin
            pending <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Packet builder
    // Keyboard: "K:" + hex(mod) + " " + hex(k0) + " " + hex(k1) +
    //           " " + hex(k2) + " " + hex(k3) + "\n"  (17 bytes)
    // Mouse:    "M:" + hex(btn) + " " + hex(dx) + " " + hex(dy) + "\n" (11 bytes)
    // -------------------------------------------------------------------------
    localparam PKT_LEN_MAX = 17;

    reg [7:0] pkt [0:PKT_LEN_MAX - 1];
    reg [4:0] pkt_idx;
    reg [4:0] pkt_len;

    function [7:0] hex_hi;
        input [7:0] b;
        begin
            hex_hi = (b[7:4] < 10) ? (8'h30 + b[7:4]) : (8'h41 + b[7:4] - 10);
        end
    endfunction

    function [7:0] hex_lo;
        input [7:0] b;
        begin
            hex_lo = (b[3:0] < 10) ? (8'h30 + b[3:0]) : (8'h41 + b[3:0] - 10);
        end
    endfunction

    // -------------------------------------------------------------------------
    // UART TX
    // -------------------------------------------------------------------------
    wire       tx_busy;
    reg  [7:0] tx_data;
    reg        tx_valid;

    uart_tx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (BAUD)
    ) tx_inst (
        .clk      (clk),
        .rst      (rst),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_busy  (tx_busy),
        .tx_pin   (uart_tx)
    );

    // -------------------------------------------------------------------------
    // Send FSM
    // -------------------------------------------------------------------------
    localparam FSM_IDLE = 2'd0;
    localparam FSM_LOAD = 2'd1;
    localparam FSM_SEND = 2'd2;
    localparam FSM_LAST = 2'd3;

    reg [1:0] fsm;
    wire sending_start = (fsm == FSM_IDLE) && pending;

    always @(posedge clk) begin
        tx_valid <= 1'b0;

        if (rst) begin
            fsm     <= FSM_IDLE;
            pkt_idx <= 5'd0;
        end else begin
            case (fsm)
                FSM_IDLE: begin
                    if (pending) begin
                        // Build packet into array
                        if (pending_is_mouse) begin
                            pkt_len <= 5'd11;
                            pkt[0]  <= 8'h4D;  // 'M'
                            pkt[1]  <= 8'h3A;  // ':'
                            pkt[2]  <= hex_hi({5'b0, pend_mbtn});
                            pkt[3]  <= hex_lo({5'b0, pend_mbtn});
                            pkt[4]  <= 8'h20;  // ' '
                            pkt[5]  <= hex_hi(pend_mdx);
                            pkt[6]  <= hex_lo(pend_mdx);
                            pkt[7]  <= 8'h20;
                            pkt[8]  <= hex_hi(pend_mdy);
                            pkt[9]  <= hex_lo(pend_mdy);
                            pkt[10] <= 8'h0A;  // '\n'
                        end else begin
                            pkt_len <= 5'd17;
                            pkt[0]  <= 8'h4B;  // 'K'
                            pkt[1]  <= 8'h3A;  // ':'
                            pkt[2]  <= hex_hi(pend_mod);
                            pkt[3]  <= hex_lo(pend_mod);
                            pkt[4]  <= 8'h20;  // ' '
                            pkt[5]  <= hex_hi(pend_k0);
                            pkt[6]  <= hex_lo(pend_k0);
                            pkt[7]  <= 8'h20;
                            pkt[8]  <= hex_hi(pend_k1);
                            pkt[9]  <= hex_lo(pend_k1);
                            pkt[10] <= 8'h20;
                            pkt[11] <= hex_hi(pend_k2);
                            pkt[12] <= hex_lo(pend_k2);
                            pkt[13] <= 8'h20;
                            pkt[14] <= hex_hi(pend_k3);
                            pkt[15] <= hex_lo(pend_k3);
                            pkt[16] <= 8'h0A;  // '\n'
                        end
                        pkt_idx <= 5'd0;
                        fsm     <= FSM_SEND;
                    end
                end

                FSM_SEND: begin
                    if (!tx_busy && !tx_valid) begin
                        tx_data  <= pkt[pkt_idx];
                        tx_valid <= 1'b1;
                        if (pkt_idx == pkt_len - 1)
                            fsm <= FSM_IDLE;
                        else
                            pkt_idx <= pkt_idx + 1'b1;
                    end
                end

                default: fsm <= FSM_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
