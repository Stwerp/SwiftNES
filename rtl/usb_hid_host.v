// Ported to iCEbreaker/iCE40
// Vendor-neutral RTL. See pll.v, usb_io.v for iCE40-specific modules.
// Pipeline register added to typ_next/x_input combinatorial decode to
// break critical path through regs[] -> casez -> typ on iCE40UP5K fabric.
//
// ---------------------------------------------------------------------------
// Copyright 2023 nand2mario
// Copyright 2026 Mateusz Nalewajski
// Copyright 2026 Aiden Cherniske
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
// ---------------------------------------------------------------------------

`default_nettype none
`timescale 1ns / 1ps

// =============================================================================
// usb_hid_host
// Top-level HID host module. Instantiates the UKP microcode processor and
// handles HID report decoding for keyboard, mouse and gamepad devices.
// =============================================================================
module usb_hid_host #(
    parameter FULL_SPEED = 0
) (
    input  wire clk,    // 96 MHz when FULL_SPEED=1, otherwise 12 MHz
    input  wire reset,  // reset
    input  wire cs,     // chip select

    input  wire usb_dm_i, usb_dp_i,  // USB D- and D+
    output wire usb_dm_o, usb_dp_o,  // USB D- and D+
    output wire usb_oe,               // USB output enable

    // device type — 0: none, 1: keyboard, 2: mouse, 3: gamepad
    output reg  [1:0] typ,
    output reg        full_report,  // pulses one cycle per complete HID report
    output wire       connerr,      // connection or protocol error
    output wire       busy,

    // keyboard
    output reg [7:0] key_modifiers,
    output reg [7:0] key_0, key_1, key_2, key_3,

    // mouse
    output reg        [2:0] mouse_btn,  // middle, right, left
    output reg signed [7:0] mouse_dx,   // signed 8-bit delta, valid during full_report
    output reg signed [7:0] mouse_dy,   // signed 8-bit delta, valid during full_report

    // gamepad
    output reg game_l, game_r, game_u, game_d,
    output reg game_a, game_b, game_x, game_y,
    output reg game_sel, game_sta,

    // debug
    output wire [63:0] dbg_hid_report,
    output wire [63:0] dbg_hid_regs,

    // ROM interface
    output wire [9:0] rom_addr,
    input  wire [3:0] rom_dout,
    output wire       rom_en
);

    // -------------------------------------------------------------------------
    // UKP interface wires
    // -------------------------------------------------------------------------
    wire       ukprdy;
    wire       ukpstb;
    wire       ukpstart;
    wire [7:0] ukpdat;
    wire [3:0] addra;
    wire [4:0] addrb;
    wire       save;
    wire       load;
    wire       connected;
    wire       full_speed;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    reg [7:0] load_data;

    reg [7:0] in_payload  [0:1];  // IN endpoint payload per VID/PID
    reg [7:0] out_payload [0:1];  // OUT endpoint payload per VID/PID

    reg       x_input;            // pad polled in X-Input mode
    reg       x_input_r;          // pipeline register for x_input

    reg [7:0] polling_interval;

    reg [7:0] dat  [0:17];  // last response bytes (up to 18 + CRC16)
    reg [7:0] regs [0:7];   // 0:VID_L 1:VID_H 2:PID_L 3:PID_H
                             // 4:INTERFACE_CLASS 5:INTERFACE_SUBCLASS 6:INTERFACE_PROTOCOL

    reg [4:0] rcvct;

    reg [1:0] typ_next;     // combinatorial device type decode
    reg [1:0] typ_next_r;   // pipeline register — breaks regs[]->casez->typ path

    reg       ukprdy_r;

    wire [15:0] vid = {regs[1], regs[0]};
    wire [15:0] pid = {regs[3], regs[2]};

    integer i, j;

    // -------------------------------------------------------------------------
    // Debug outputs
    // -------------------------------------------------------------------------
    assign dbg_hid_report = {dat[7],  dat[6],  dat[5],  dat[4],
                             dat[3],  dat[2],  dat[1],  dat[0]};
    assign dbg_hid_regs   = {regs[7], regs[6], regs[5], regs[4],
                             regs[3], regs[2], regs[1], regs[0]};

    // -------------------------------------------------------------------------
    // UKP microcode processor
    // -------------------------------------------------------------------------
    ukp #(
        .FULL_SPEED (FULL_SPEED)
    ) ukp (
        .reset      (reset),
        .clk        (clk),
        .cs         (cs),
        .usb_dp_i   (usb_dp_i),
        .usb_dm_i   (usb_dm_i),
        .usb_dp_o   (usb_dp_o),
        .usb_dm_o   (usb_dm_o),
        .usb_oe     (usb_oe),
        .ukprdy     (ukprdy),
        .ukpstb     (ukpstb),
        .ukpstart   (ukpstart),
        .ukpdat     (ukpdat),
        .addra      (addra),
        .addrb      (addrb),
        .save       (save),
        .load       (load),
        .load_data  (load_data),
        .connected  (connected),
        .full_speed (full_speed),
        .connerr    (connerr),
        .busy       (busy),
        .rom_addr   (rom_addr),
        .rom_dout   (rom_dout),
        .rom_en     (rom_en)
    );

    // -------------------------------------------------------------------------
    // Save and load instruction handler
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset || connerr) begin
            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= 8'b0;
            end
        end else if (save) begin
            if (addra < 8 && addrb < 18) begin
                regs[addra[2:0]] <= dat[addrb];
            end
        end else if (load) begin
            if (addra < 8) begin
                load_data <= regs[addra[2:0]];
            end else if (addra == 8) begin   // IN payload byte 0
                load_data <= in_payload[0];
            end else if (addra == 9) begin   // IN payload byte 1
                load_data <= in_payload[1];
            end else if (addra == 10) begin  // OUT payload byte 0
                load_data <= out_payload[0];
            end else if (addra == 11) begin  // OUT payload byte 1
                load_data <= out_payload[1];
            end else if (addra == 12) begin  // X-Input flag
                load_data <= x_input_r ? 8'b1 : 8'b0;
            end else if (addra == 13) begin  // polling interval
                load_data <= polling_interval;
            end
        end
    end

    // -------------------------------------------------------------------------
    // UKP packet data handler
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset || connerr) begin
            for (j = 0; j < 18; j = j + 1) begin
                dat[j] <= 8'b0;
            end
            ukprdy_r    <= 1'b0;
            typ         <= 2'b0;
            full_report <= connerr;  // send empty report on connection error
            rcvct       <= 5'b0;

        end else if (ukpstart) begin
            rcvct       <= 5'b0;
            full_report <= 1'b0;

        end else if (ukprdy) begin
            ukprdy_r    <= ukprdy;
            full_report <= 1'b0;
            if (ukpstb) begin
                if (rcvct < 20) begin  // 18 data bytes plus CRC16
                    rcvct <= rcvct + 1;
                end
                if (rcvct < 18) begin
                    dat[rcvct] <= ukpdat;
                end
            end

        end else begin
            ukprdy_r    <= ukprdy;
            full_report <= 1'b0;
            typ         <= connected ? typ_next_r : 2'b0;

            if (ukprdy_r) begin  // individual packet received
                rcvct       <= rcvct - 2;       // discard CRC16
                full_report <= (typ != 2'b0);   // strobe when connected
            end

            if (connected && typ != typ_next_r) begin
                for (j = 0; j < 18; j = j + 1) begin
                    dat[j] <= 8'b0;
                end
                full_report <= 1'b1;  // send empty report on device type change
            end
        end
    end

    // -------------------------------------------------------------------------
    // Device type decode — combinatorial
    // Decodes INTERFACE_CLASS, INTERFACE_SUBCLASS, INTERFACE_PROTOCOL from
    // regs[] into typ_next and x_input. Wide casez over 24 bits maps to a
    // deep LUT chain on iCE40 — registered below to break the critical path.
    // -------------------------------------------------------------------------
    always @(*) begin
        typ_next = 2'd0;
        x_input  = 1'b0;

        casez ({regs[4], regs[5], regs[6]})
            {8'h03, 8'h01, 8'h01}: begin
                typ_next = 2'd1;              // keyboard
            end
            {8'h03, 8'h01, 8'hzz}: begin
                typ_next = 2'd2;              // mouse
            end
            {8'h03, 8'hzz, 8'hzz}: begin
                typ_next = 2'd3;              // other HID (incl. 8BitDo D-Input)
            end
            {8'hff, 8'h5d, 8'h01},
            {8'hff, 8'h5d, 8'h81}: begin
                typ_next = 2'd3;              // Xbox 360-compatible (X-Input)
                x_input  = 1'b1;              // wired=01, wireless=81
            end
            default: begin
                typ_next = 2'd0;
                x_input  = 1'b0;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Pipeline register — breaks regs[] -> casez -> typ critical path.
    // One-cycle latency is safe: device type only changes at enumeration,
    // never during HID report polling.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        typ_next_r <= typ_next;
        x_input_r  <= x_input;
    end

    // -------------------------------------------------------------------------
    // IN/OUT endpoint payload — per VID/PID
    // -------------------------------------------------------------------------
    always @(*) begin
        casez ({vid, pid})
            {16'h2dc8, 16'h301c},
            {16'h2dc8, 16'h310a}: begin
                in_payload[0]  = 8'h01;  // IN endpoint 4
                in_payload[1]  = 8'hba;
                out_payload[0] = 8'h81;  // OUT endpoint 5
                out_payload[1] = 8'h0a;
            end  // 8BitDo Ultimate 2C
            default: begin
                in_payload[0]  = 8'h81;  // IN endpoint 1 (default)
                in_payload[1]  = 8'h58;
                out_payload[0] = 8'h01;  // OUT endpoint 2 (default)
                out_payload[1] = 8'hc1;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Polling interval — per device type, speed, VID/PID
    // -------------------------------------------------------------------------
    always @(*) begin
        casez ({typ, full_speed, x_input_r, vid, pid})
            {2'bzz, 1'b0, 1'bz, 16'hzzzz, 16'hzzzz}: begin
                polling_interval = 8'd10;  // low-speed devices
            end
            {2'b10, 1'b1, 1'b0, 16'hzzzz, 16'hzzzz}: begin
                polling_interval = 8'd2;   // full-speed mouse
            end
            {2'b01, 1'b1, 1'b0, 16'hzzzz, 16'hzzzz}: begin
                polling_interval = 8'd8;   // full-speed keyboard
            end
            {2'b11, 1'b1, 1'bz, 16'h2dc8, 16'hzzzz}: begin
                polling_interval = 8'd2;   // 8BitDo
            end
            {2'b11, 1'b1, 1'b1, 16'hzzzz, 16'hzzzz}: begin
                polling_interval = 8'd4;   // other Xbox-compatible
            end
            default: begin
                polling_interval = 8'd8;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // HID report decode — maps dat[] bytes to HID outputs per device type
    // -------------------------------------------------------------------------
    reg [2:0] hat;

    always @(*) begin
        // default all outputs to zero
        {key_modifiers, key_0, key_1, key_2, key_3} = 40'h0;
        {mouse_btn, mouse_dx, mouse_dy}              = 19'h0;
        {game_l, game_r, game_u, game_d}             = 4'b0;
        {game_y, game_x, game_b, game_a}             = 4'b0;
        {game_sel, game_sta}                         = 2'b0;
        hat                                          = 3'b0;

        if (typ == 2'd1) begin
            // keyboard — dat[0]=modifiers, dat[2..5]=keycodes
            key_modifiers = dat[0];
            key_0         = dat[2];
            key_1         = dat[3];
            key_2         = dat[4];
            key_3         = dat[5];

        end else if (typ == 2'd2) begin
            // mouse — dat[0][2:0]=buttons, dat[1]=dx, dat[2]=dy
            mouse_btn = dat[0][2:0];
            mouse_dx  = dat[1];
            mouse_dy  = dat[2];

        end else if (typ == 2'd3) begin
            casez ({x_input_r, vid, pid})

                {1'bz, 16'h2dc8, 16'h301c}: begin
                    // 8BitDo Ultimate 2C — idle report, no action
                end

                {1'b0, 16'h2dc8, 16'hzzzz}: begin
                    // 8BitDo generic D-Input
                    game_y   = dat[1][4];
                    game_x   = dat[1][3];
                    game_b   = dat[1][1];
                    game_a   = dat[1][0];
                    game_sel = dat[2][2];
                    game_sta = dat[2][3];

                    if (dat[3][3:0] != 4'hf) begin
                        hat    = dat[3][2:0];
                        game_u = (hat == 3'd0 || hat == 3'd1 || hat == 3'd7);
                        game_d = (hat == 3'd3 || hat == 3'd4 || hat == 3'd5);
                        game_l = (hat == 3'd5 || hat == 3'd6 || hat == 3'd7);
                        game_r = (hat == 3'd1 || hat == 3'd2 || hat == 3'd3);
                    end

                    game_d = game_d || dat[1][6];  // LB
                    game_u = game_u || dat[1][7];  // RB
                    game_a = game_a || dat[2][0];  // LT
                    game_b = game_b || dat[2][1];  // RT
                end

                {1'b1, 16'hzzzz, 16'hzzzz}: begin
                    // Xbox 360-compatible (X-Input)
                    if (dat[0] == 8'h00) begin  // valid pad report
                        game_y   = dat[3][7];
                        game_x   = dat[3][6];
                        game_b   = dat[3][5];
                        game_a   = dat[3][4];
                        game_sel = dat[2][5];
                        game_sta = dat[2][4];

                        game_r = dat[2][3];
                        game_l = dat[2][2];
                        game_d = dat[2][1];
                        game_u = dat[2][0];

                        game_d = game_d || dat[3][0];  // LB
                        game_u = game_u || dat[3][1];  // RB
                        game_a = game_a || (|dat[4]);  // LT
                        game_b = game_b || (|dat[5]);  // RT
                    end
                end

                {1'b0, 16'h0738, 16'h2217}: begin
                    // SpeedLink Competition PRO Extra
                    game_y = dat[0][2];
                    game_x = dat[0][0];
                    game_b = dat[0][3];
                    game_a = dat[0][1];

                    game_l = (dat[1][7:6] == 2'b00);
                    game_r = (dat[1][7:6] == 2'b11);
                    game_u = (dat[2][7:6] == 2'b00);
                    game_d = (dat[2][7:6] == 2'b11);
                end

                default: begin
                    // Generic gamepad layout
                    // dat[3]=X axis, dat[4]=Y axis
                    // dat[5][7:4]=YBAX, dat[6][5:4]=START/SELECT
                    game_l = (dat[3][7:6] == 2'b00);
                    game_r = (dat[3][7:6] == 2'b11);
                    game_u = (dat[4][7:6] == 2'b00);
                    game_d = (dat[4][7:6] == 2'b11);

                    game_a   = dat[5][5];
                    game_b   = dat[5][6];
                    game_x   = dat[5][4];
                    game_y   = dat[5][7];
                    game_sel = dat[6][4];
                    game_sta = dat[6][5];
                end

            endcase
        end
    end

endmodule

// =============================================================================
// ukp
// UKP microcode processor. Executes instructions from the external ROM to
// drive USB transactions and handle device enumeration.
// =============================================================================
module ukp #(
    parameter FULL_SPEED = 0
) (
    input  wire clk,
    input  wire reset,
    input  wire cs,

    input  wire usb_dm_i, usb_dp_i,  // USB D- and D+
    output wire usb_dm_o, usb_dp_o,  // USB D- and D+
    output wire usb_oe,               // USB output enable

    output reg        ukprdy,    // data frame is outputting
    output reg        ukpstb,    // strobe for a byte within the frame
    output reg        ukpstart,  // marks start of read transaction
    output reg  [7:0] ukpdat,    // output data when ukpstb=1

    output reg  [3:0] addra,
    output reg  [4:0] addrb,
    output reg        save,
    output reg        load,
    input  wire [7:0] load_data,

    output wire [9:0] rom_addr,
    input  wire [3:0] rom_dout,
    output wire       rom_en,

    output reg  connected,
    output reg  full_speed,
    output wire connerr,
    output wire busy
);

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    localparam S_OPCODE = 5'd0;
    localparam S_SYNC   = 5'd1;
    localparam S_WAIT   = 5'd2;
    localparam S_LDI0   = 5'd3;
    localparam S_LDI1   = 5'd4;
    localparam S_BX     = 5'd5;
    localparam S_B0     = 5'd6;
    localparam S_B1     = 5'd7;
    localparam S_B2     = 5'd8;
    localparam S_HIZ    = 5'd9;
    localparam S_RX0    = 5'd10;
    localparam S_RX1    = 5'd11;
    localparam S_TXR0   = 5'd12;
    localparam S_TX0    = 5'd13;
    localparam S_TX1    = 5'd14;
    localparam S_TX2    = 5'd15;
    localparam S_SAVE0  = 5'd16;
    localparam S_SAVE1  = 5'd17;
    localparam S_LOAD0  = 5'd18;
    localparam S_LOAD1  = 5'd19;
    localparam S_LOAD2  = 5'd20;

    // -------------------------------------------------------------------------
    // Internal wires
    // -------------------------------------------------------------------------
    wire [3:0] inst;
    wire       polarity;
    wire       sample;
    wire       transmission;
    wire       data01;
    wire       payload;
    wire       eop;
    wire       di;
    wire       dbit;
    wire       timing_0, timing_1, timing_3;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    reg  [3:0] insth;
    reg  [7:0] wk;          // W register
    reg  [7:0] sb;          // output shift register
    reg  [2:0] sadr;        // out4/outb write pointer
    reg  [2:0] timing;      // T register (0~7)
    reg  [2:0] prescaler;   // clock prescaler for low-speed
    reg  [3:0] lb4;
    reg [16:0] interval;
    reg  [7:0] data;        // received data shift register
    reg  [2:0] nrztxct;     // NRZI transmit bit-stuff counter
    reg  [2:0] nrzrxct;     // NRZI receive bit-stuff counter
    reg  [9:0] conct;       // watchdog counter
    reg  [8:0] bitaddr;     // bit address within packet (0~512)

    reg ug;     // USB output enable (drives usb_oe)
    reg up;     // USB D+ drive value
    reg um;     // USB D- drive value
    reg dpi;    // registered D+ input
    reg dmi;    // registered D- input
    reg dis;    // previous di sample
    reg did;    // previous di for edge detection
    reg cond;   // branch condition
    reg eot;    // end of transmission
    reg nak;    // NAK received
    reg stall;  // STALL received

    reg [4:0] state, state_next;
    reg [9:0] pc, pc_next;
    reg [9:0] wpc [0:1];

    // -------------------------------------------------------------------------
    // Combinatorial assignments
    // -------------------------------------------------------------------------
`ifdef VERILATOR
    wire interval_frame = interval == 30;
`else
    wire interval_frame = interval == (FULL_SPEED ? 17'd96000 : 17'd12000);
`endif

    assign polarity = full_speed;

    assign di   = polarity ? dpi : dmi;
    assign dbit = sb[7 - sadr[2:0]];

    assign usb_dp_o = up;
    assign usb_dm_o = um;
    assign usb_oe   = ug;

    assign connerr = (&conct) && (di || connected);

    assign inst     = rom_dout;
    assign rom_addr = pc_next;
    assign rom_en   = state_next != S_SYNC  &&
                      state_next != S_WAIT  &&
                      state_next != S_HIZ   &&
                      state_next != S_RX0   &&
                      state_next != S_RX1   &&
                      state_next != S_TXR0  &&
                      state_next != S_TX2   &&
                      state_next != S_LOAD1 &&
                      state_next != S_LOAD2;

    assign timing_0 = (timing == 3'd0) && (prescaler == 3'd0);
    assign timing_1 = (timing == 3'd1) && (prescaler == 3'd0);
    assign timing_3 = (timing == 3'd3) && (prescaler == 3'd0);

    assign sample       = (state == S_RX1) && timing_3;
    assign transmission = (state == S_TX2) && timing_0;
    assign eop          = (dpi == dmi);  // EOP or line error

    assign data01 = (bitaddr == 9'd16) &&
                    (data[3:0] == 4'b0011 || data[3:0] == 4'b1011);
    assign payload = (nrzrxct != 3'd6) && (bitaddr > 9'd15) && !eop;

    assign busy = (insth != 4'd14);  // not WAIT instruction

    // -------------------------------------------------------------------------
    // Register USB inputs
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        dpi <= usb_dp_i;
        dmi <= usb_dm_i;
    end

    // -------------------------------------------------------------------------
    // Branch condition decode — combinatorial
    // -------------------------------------------------------------------------
    always @(*) begin
        case (inst)
            4'd0: cond = eop || (connected && !di) || (!FULL_SPEED && !dmi);  // BE
            4'd1: cond = connected;                                             // BC
            4'd2: cond = nak;                                                   // BNAK
            4'd3: cond = stall;                                                 // BSTALL
            4'd4: cond = (wk > 8'd0);                                          // BNZ
            4'd5: cond = (wk == 8'd0);                                         // BZ
            4'd6: cond = !full_speed;                                           // BNF
            4'd7: cond = 1'b1;                                                  // BJMP
            default: cond = 1'b0;
        endcase
    end

    // -------------------------------------------------------------------------
    // State machine — sequential
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        state <= state_next;
        pc    <= pc_next;
    end

    // -------------------------------------------------------------------------
    // State machine — combinatorial next-state logic
    // -------------------------------------------------------------------------
    always @(*) begin
        if (reset || (&conct)) begin
            state_next = S_OPCODE;
            pc_next    = 10'd0;
        end else begin
            state_next = state;
            pc_next    = pc + 10'd1;

            case (state)
                S_OPCODE: begin
                    case (inst)
                        4'd0:  ;                                    // NOP
                        4'd1:  state_next = S_LDI0;                // LDI
                        4'd2:  ;                                    // START
                        4'd3:  state_next = S_TX0;                 // OUT4
                        4'd4:  ;
                        4'd5:  begin
                            state_next = S_HIZ;
                            pc_next    = pc;
                        end                                         // HIZ
                        4'd6:  state_next = S_TX0;                 // OUTB
                        4'd7:  pc_next = wpc[0];                   // RET
                        4'd8:  state_next = S_B0;                  // CALL
                        4'd9:  state_next = S_BX;                  // BX
                        4'd10: begin
                            state_next = S_TXR0;
                            pc_next    = pc;
                        end                                         // OUTR
                        4'd11: ;                                    // DEC
                        4'd12: state_next = S_SAVE0;               // SAVE
                        4'd13: begin
                            state_next = S_RX0;
                            pc_next    = pc;
                        end                                         // IN
                        4'd14: begin
                            state_next = S_WAIT;
                            pc_next    = pc;
                        end                                         // WAIT
                        4'd15: state_next = S_LOAD0;               // LOAD
                        default: ;
                    endcase
                end
                S_SYNC: begin
                    if (timing_1) begin
                        state_next = S_OPCODE;
                    end else begin
                        pc_next = pc;
                    end
                end
                S_WAIT: begin
                    if (interval_frame) begin
                        state_next = S_OPCODE;
                    end else begin
                        pc_next = pc;
                    end
                end
                S_LDI0: state_next = S_LDI1;
                S_LDI1: state_next = S_OPCODE;
                S_BX: begin
                    if (cond) begin
                        state_next = S_B0;
                    end else begin
                        state_next = S_OPCODE;
                        pc_next    = pc + 10'd3;
                    end
                end
                S_B0: state_next = S_B1;
                S_B1: begin
                    state_next = S_OPCODE;
                    pc_next    = {inst, lb4, 2'b00};
                end
                S_RX0: begin
                    if (!di) begin
                        state_next = S_RX1;
                    end else begin
                        pc_next = pc;
                    end
                end
                S_HIZ: begin
                    pc_next = pc;
                    if (timing_0) begin
                        state_next = S_SYNC;
                    end
                end
                S_RX1: begin
                    if (sample && eop) begin
                        state_next = S_SYNC;
                    end else begin
                        pc_next = pc;
                    end
                end
                S_TXR0: begin
                    state_next = S_TX2;
                    pc_next    = pc;
                end
                S_TX0: state_next = S_TX1;
                S_TX1: begin
                    state_next = S_TX2;
                    pc_next    = pc;
                end
                S_TX2: begin
                    if (eot && timing_1) begin
                        state_next = S_OPCODE;
                    end else begin
                        pc_next = pc;
                    end
                end
                S_SAVE0: state_next = S_SAVE1;
                S_SAVE1: state_next = S_OPCODE;
                S_LOAD0: begin
                    state_next = S_LOAD1;
                    pc_next    = pc;
                end
                S_LOAD1: begin
                    state_next = S_LOAD2;
                    pc_next    = pc;
                end
                S_LOAD2: state_next = S_OPCODE;
                default: state_next = S_OPCODE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Main sequential block — register outputs and datapath
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset || (&conct)) begin
            conct      <= 10'd0;
            connected  <= 1'b0;
            timing     <= 3'd0;
            prescaler  <= 3'd0;
            bitaddr    <= 9'd0;
            nak        <= 1'b0;
            stall      <= 1'b1;
            eot        <= 1'b0;
            ug         <= 1'b0;
            interval   <= 17'd1;
            full_speed <= FULL_SPEED[0];
            save       <= 1'b0;
            load       <= 1'b0;
            ukpstb     <= 1'b0;
            ukprdy     <= 1'b0;
            ukpstart   <= 1'b0;

        end else if (cs) begin
            // clear strobes each cycle
            save     <= 1'b0;
            load     <= 1'b0;
            ukpstb   <= 1'b0;
            ukpstart <= 1'b0;

            // prescaler — divides clock for low-speed operation
            if (FULL_SPEED && !full_speed) begin
                prescaler <= prescaler + 3'd1;
            end else begin
                prescaler <= 3'd0;
            end

            // timing — resets on bus edge when not driving
            did <= di;
            if (!ug && di != did) begin
                timing <= 3'd0;
            end else if (prescaler == 3'd0) begin
                timing <= timing + 3'd1;
            end

            // SOF frame interval counter
            if (interval_frame) begin
                interval <= 17'd1;
            end else begin
                interval <= interval + 17'd1;
            end

            // watchdog — reset on valid data byte or NAK, increment on SOF
            if (ukpstb || (connected && nak)) begin
                conct <= 10'd0;
            end else if (interval_frame) begin
                conct <= conct + 10'd1;
            end

            // state machine register outputs
            case (state)
                S_OPCODE: begin
                    insth <= inst;
                    case (inst)
                        4'd0:  ;                                    // NOP
                        4'd1:  ;                                    // LDI
                        4'd2:  begin
                            ukpstart <= 1'b1;                       // START
                        end
                        4'd3:  begin
                            sadr <= 3'd3;                           // OUT4
                        end
                        4'd4:  ;
                        4'd5:  ;                                    // HIZ
                        4'd6:  begin
                            sadr <= 3'd7;                           // OUTB
                        end
                        4'd7:  begin
                            wpc[0] <= wpc[1];                       // RET
                        end
                        4'd8:  begin
                            wpc[0] <= pc + 10'd3;                   // CALL
                            wpc[1] <= wpc[0];
                        end
                        4'd9:  ;                                    // BX
                        4'd10: begin
                            sadr <= 3'd7;                           // OUTR
                        end
                        4'd11: begin
                            if (wk > 8'd0) begin                    // DEC
                                wk <= wk - 8'd1;
                            end
                        end
                        4'd12: ;                                    // SAVE
                        4'd13: begin
                            dis <= di;                              // IN
                        end
                        4'd14: ;                                    // WAIT
                        4'd15: ;                                    // LOAD
                        default: ;
                    endcase
                end
                S_SYNC: begin
                    if (timing_0) begin
                        ukprdy <= 1'b0;
                    end
                end
                S_WAIT: ;
                S_LDI0: begin
                    wk[3:0] <= inst;
                end
                S_LDI1: begin
                    wk[7:4] <= inst;
                end
                S_BX: begin
                    case (inst)
                        4'd0: begin
                            if (!cond && !connected && FULL_SPEED) begin  // BE
                                full_speed <= dpi;
                            end
                        end
                        default: ;
                    endcase
                end
                S_B0: begin
                    lb4 <= inst;
                end
                S_B1: ;
                S_HIZ: begin
                    if (timing_0) begin
                        ug <= 1'b0;
                    end
                end
                S_RX0: begin
                    bitaddr <= 9'd0;
                    nak     <= 1'b0;
                    stall   <= 1'b1;
                    eot     <= 1'b0;
                    nrzrxct <= 3'd0;
                    timing  <= 3'd0;
                    ukprdy  <= 1'b0;
                end
                S_RX1: begin
                    if (sample) begin
                        if (data01) begin
                            wk     <= wk - 8'd1 + 8'd16;  // account for CRC16
                            ukprdy <= 1'b1;
                        end else if (payload && wk > 8'd0) begin
                            wk <= wk - 8'd1;
                        end else if (eot) begin
                            ukprdy <= 1'b0;
                        end
                    end
                end
                S_TXR0: begin
                    sb  <= wk;
                    eot <= 1'b0;
                end
                S_TX0: begin
                    sb[3:0] <= inst;
                    eot     <= 1'b0;
                end
                S_TX1: begin
                    sb[7:4] <= inst;
                end
                S_TX2: ;
                S_SAVE0: begin
                    addra <= inst;
                    addrb <= wk[4:0];
                end
                S_SAVE1: begin
                    addrb <= addrb + {1'b0, inst};
                    if (addra == 4'd15) begin
                        connected <= (inst != 4'd0);
                        conct     <= 10'd0;
                    end else begin
                        save <= 1'b1;
                    end
                end
                S_LOAD0: begin
                    addra <= inst;
                    load  <= 1'b1;
                end
                S_LOAD1: ;
                S_LOAD2: begin
                    wk <= load_data;
                end
                default: ;
            endcase

            // ----------------------------------------------------------------
            // Sampling — executes when sample strobe is active in S_RX1
            // ----------------------------------------------------------------
            if (sample) begin
                ug  <= 1'b0;
                dis <= di;
                eot <= (eop || wk == 8'd0);

                if (bitaddr == 9'd16) begin
                    nak   <= (data[3:0] == 4'b1010);
                    stall <= (data[3:0] == 4'b1110);
                end

                if (nrzrxct != 3'd6 && !(&bitaddr)) begin
                    data[6:0] <= data[7:1];
                    data[7]   <= (dis == di);
                    bitaddr   <= bitaddr + 9'd1;
                end

                if (dis == di) begin
                    nrzrxct <= nrzrxct + 3'd1;
                end else begin
                    nrzrxct <= 3'd0;
                end

                if (ukprdy && bitaddr[2:0] == 3'b000) begin
                    ukpdat <= data;
                    ukpstb <= 1'b1;
                end
            end

            // ----------------------------------------------------------------
            // Transmission — executes when transmission strobe is active in S_TX2
            // ----------------------------------------------------------------
            if (transmission) begin
                ug <= 1'b1;

                if (!ug) begin
                    nrztxct <= 3'd0;
                end else if (dbit) begin
                    nrztxct <= nrztxct + 3'd1;
                end else begin
                    nrztxct <= 3'd0;
                end

                if (insth == 4'd6 || insth == 4'd10) begin  // OUTB or OUTR
                    if (nrztxct != 3'd6) begin
                        up <= dbit ?  up : ~up;
                        um <= dbit ? ~up :  up;
                    end else begin
                        up      <= ~up;
                        um      <=  up;
                        nrztxct <= 3'd0;
                    end
                end else begin  // OUT4
                    up <= sb[{sadr[2] | ~polarity, sadr[1:0]}];
                    um <= sb[{sadr[2] |  polarity, sadr[1:0]}];
                end

                if (nrztxct != 3'd6) begin
                    if (sadr > 3'd0) begin
                        sadr <= sadr - 3'd1;
                    end else begin
                        eot <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
// vim:ts=4 sw=4 tw=120 et