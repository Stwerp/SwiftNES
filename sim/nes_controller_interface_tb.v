// Testbench for NES Controller Interface
// Simulates NES console reading the controller

`timescale 1ns/1ps

module nes_controller_interface_tb;

    // Testbench signals
    reg clk;
    reg rst_n;
    
    // Button inputs
    reg btn_a, btn_b, btn_select, btn_start;
    reg btn_up, btn_down, btn_left, btn_right;
    
    // NES signals
    reg nes_clk;
    reg nes_latch;
    wire nes_data;
    
    // Expected data
    reg [7:0] expected_data;
    reg [7:0] received_data;
    integer bit_count;
    
    // Instantiate the NES controller interface
    nes_controller_interface dut (
        .clk(clk),
        .rst_n(rst_n),
        .btn_a(btn_a),
        .btn_b(btn_b),
        .btn_select(btn_select),
        .btn_start(btn_start),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .nes_clk(nes_clk),
        .nes_latch(nes_latch),
        .nes_data(nes_data)
    );
    
    // Clock generation (12 MHz)
    initial begin
        clk = 0;
        forever #41.67 clk = ~clk;  // 12 MHz = 83.33ns period
    end
    
    // Simulation control
    initial begin
        $dumpfile("nes_controller_interface_tb.vcd");
        $dumpvars(0, nes_controller_interface_tb);
        
        // Initialize signals
        rst_n = 0;
        nes_clk = 0;
        nes_latch = 0;
        btn_a = 0;
        btn_b = 0;
        btn_select = 0;
        btn_start = 0;
        btn_up = 0;
        btn_down = 0;
        btn_left = 0;
        btn_right = 0;
        
        // Reset
        #200;
        rst_n = 1;
        #200;
        
        $display("Starting NES Controller Interface Testbench");
        $display("============================================");
        
        // Test 1: No buttons pressed
        $display("\nTest 1: No buttons pressed");
        test_controller_read(8'hFF);  // All 1s = no buttons
        
        // Test 2: A button pressed
        $display("\nTest 2: A button pressed");
        btn_a = 1;
        #100;
        test_controller_read(8'hFE);  // Bit 0 = 0
        btn_a = 0;
        
        // Test 3: B button pressed
        $display("\nTest 3: B button pressed");
        btn_b = 1;
        #100;
        test_controller_read(8'hFD);  // Bit 1 = 0
        btn_b = 0;
        
        // Test 4: Start button pressed
        $display("\nTest 4: Start button pressed");
        btn_start = 1;
        #100;
        test_controller_read(8'hF7);  // Bit 3 = 0
        btn_start = 0;
        
        // Test 5: Multiple buttons (A + B + Start)
        $display("\nTest 5: Multiple buttons (A + B + Start)");
        btn_a = 1;
        btn_b = 1;
        btn_start = 1;
        #100;
        test_controller_read(8'hF4);  // Bits 0, 1, 3 = 0
        btn_a = 0;
        btn_b = 0;
        btn_start = 0;
        
        // Test 6: D-Pad Up
        $display("\nTest 6: D-Pad Up");
        btn_up = 1;
        #100;
        test_controller_read(8'hEF);  // Bit 4 = 0
        btn_up = 0;
        
        // Test 7: D-Pad Right
        $display("\nTest 7: D-Pad Right");
        btn_right = 1;
        #100;
        test_controller_read(8'h7F);  // Bit 7 = 0
        btn_right = 0;
        
        // Test 8: All buttons pressed
        $display("\nTest 8: All buttons pressed");
        btn_a = 1;
        btn_b = 1;
        btn_select = 1;
        btn_start = 1;
        btn_up = 1;
        btn_down = 1;
        btn_left = 1;
        btn_right = 1;
        #100;
        test_controller_read(8'h00);  // All bits = 0
        
        #1000;
        $display("\nTestbench completed successfully!");
        $finish;
    end
    
    // Task to simulate NES controller read
    task test_controller_read;
        input [7:0] expected;
        integer i;
        begin
            expected_data = expected;
            received_data = 8'h00;
            
            // Pulse latch
            #1000;
            nes_latch = 1;
            #12000;  // 12us latch pulse
            nes_latch = 0;
            #2000;
            
            // Read first bit (available immediately after latch)
            received_data[0] = nes_data;
            
            // Clock out remaining 7 bits
            for (i = 1; i < 8; i = i + 1) begin
                #6000;  // Wait before clock pulse
                nes_clk = 1;
                #6000;  // Clock high time
                nes_clk = 0;
                #2000;  // Setup time
                received_data[i] = nes_data;
            end
            
            // Check result
            #1000;
            if (received_data == expected_data) begin
                $display("  PASS: Received 0x%02h, Expected 0x%02h", received_data, expected_data);
            end else begin
                $display("  FAIL: Received 0x%02h, Expected 0x%02h", received_data, expected_data);
                $display("        Bit pattern: %08b vs %08b", received_data, expected_data);
            end
        end
    endtask

endmodule
