`default_nettype none
`timescale 1ns / 1ps

// UKP microcode ROM — 1024 x 4-bit
// Synthesis attribute forces Yosys to use iCE40 EBR (one SB_RAM40_4K block)
// rather than LUT RAM. Content loaded from usb_hid_host_rom.mem at synthesis.
// Interface is synchronous read with active-high enable, matching the
// read timing expected by the ukp state machine in usb_hid_host.v.
module usb_hid_host_rom (
    input wire clk,
    input wire [9:0] addr, // 10-bit address for 1024 words
    input wire en,         // active-high enable for reading
    output reg [3:0] dout  // 4-bit data output
);

`ifndef USB_HID_HOST_ROM_MEMFILE
`define USB_HID_HOST_ROM_MEMFILE "rom/usb_hid_host_rom.mem"
`endif

    (* ram_style = "block" *)
    reg [3:0] mem [0:1023]; // 1024 x 4-bit ROM

    initial begin
        $readmemh(`USB_HID_HOST_ROM_MEMFILE, mem); // Load ROM content from file
    end

    always @(posedge clk) begin
        if (en)
            dout <= mem[addr]; // Output data at given address when enabled
    end

endmodule

`default_nettype wire
