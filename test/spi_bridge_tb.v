`default_nettype none
`timescale 1ns/1ns
`include "src/spi_bridge.v" // Assuming the file is named this

module tb_spi_bridge;

    // --- Signal Declarations ---
    reg clk;      // System clock (unused in DUT logic but present in port)
    reg rst_n;    // Active low reset
    reg sclk;     // SPI Clock
    reg cs_n;     // Chip Select
    reg mosi;     // Master Out Slave In
    reg [7:0] data_out_stim; // Data provided TO the DUT (to be sent out MISO)

    wire miso;
    wire byte_sync;
    wire [7:0] data_in; // Data received BY the DUT (from MOSI)

    // --- DUT Instantiation ---
    spi_bridge DUT (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out_stim)
    );

    // --- Clock Generation ---
    // SCLK Period = 20ns (50MHz equivalent)
    localparam CLK_PERIOD = 20;
    initial sclk = 0;
    always #(CLK_PERIOD/2) sclk = ~sclk;

    // Unused system clock generation (just in case)
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Tasks for Clean Testing ---

    // Task to Reset the system
    task apply_reset;
    begin
        rst_n = 0;
        cs_n = 1;
        mosi = 0;
        // sclk = 0;
        data_out_stim = 8'h00;
        #(CLK_PERIOD);
        rst_n = 1;
        #10;
    end
    endtask

    // Task to mimic SPI Master sending a byte (MSB First)
    task master_send_byte;
        input [7:0] data_to_send;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                // Drive data on Negative Edge so it is stable for DUT's Positive Edge
                mosi = data_to_send[i];
                #(CLK_PERIOD);
            end
            // Wait for the final bit to be processed
            @(negedge sclk);
        end
    endtask

    // Task to check if DUT received the byte correctly
    task check_received_data;
        input [7:0] expected_data;
        begin
            // Wait a moment for byte_sync to propagate
            #1; 
            if (data_in === expected_data && byte_sync === 1'b1) begin
                $display("[PASS] DUT Received 0x%h correctly. byte_sync is HIGH.", data_in);
            end else begin
                $display("[FAIL] DUT Expected 0x%h, Got 0x%h. byte_sync=%b", expected_data, data_in, byte_sync);
            end
        end
    endtask

    // Task to read byte from DUT (MISO)
    // Note: Analysis of your code shows MISO sends LSB first based on `data_out[bits_written]`
    task master_read_byte_and_check;
        input [7:0] expected_data;
        reg [7:0] collected_data;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                collected_data[i] = miso; 
                #(CLK_PERIOD);
            end
            
            if (collected_data === expected_data) begin
                $display("[PASS] Master Read 0x%h correctly from MISO.", collected_data);
            end else begin
                $display("[FAIL] Master Expected 0x%h, Got 0x%h from MISO.", expected_data, collected_data);
            end
        end
    endtask


    // --- Main Test Sequence ---
    initial begin
        $dumpfile("build/spi_bridge_test.vcd");
        $dumpvars(0, tb_spi_bridge);

        $display("--- Starting SPI Bridge Simulation ---");

        // 1. Reset
        apply_reset();

        // ==========================================
        // TEST CASE 1: WRITE TO DUT (Master -> DUT)
        // ==========================================
        $display("\nTest 1: Master Writes 0xA5 to DUT");
        
        // Assert Chip Select
        #(CLK_PERIOD/2);
        cs_n = 0;

        // A. Send Command Byte
        // Bit 7 (MSB) must be 0 to trigger 'is_read' (Write to DUT) in your logic.
        // 0x00 = Binary 00000000.
        master_send_byte(8'h00); 
        $display("Command Byte Sent (Mode: Write to DUT)");

        // B. Send Data Byte
        master_send_byte(8'hA5);
        
        // C. Verify
        check_received_data(8'hA5);

        // Deassert CS
        #(CLK_PERIOD/2);
        cs_n = 1;
        #10;


        // ==========================================
        // TEST CASE 2: READ FROM DUT (DUT -> Master)
        // ==========================================
        $display("\nTest 2: Master Reads 0x3C from DUT");
        
        // Pre-load the data we want the DUT to send back

        // Assert Chip Select
        #(CLK_PERIOD);
        apply_reset();

        data_out_stim = 8'h3C; // Binary 00111100

        cs_n = 0;

        // A. Send Command Byte
        // Bit 7 (MSB) must be 1 to trigger 'is_write' (Read from DUT) in your logic.
        // 0x80 = Binary 10000000.
        master_send_byte(8'h80);
        $display("Command Byte Sent (Mode: Read from DUT)");

        // B. Master clocks out dummy bits on MOSI while reading MISO
        // Your logic sends LSB first (data_out[0], then [1]...). 
        master_read_byte_and_check(8'h3C);

        // Deassert CS
        #(CLK_PERIOD/2);
        cs_n = 1;
        #40;

        $display("\n--- Simulation Complete ---");
        $finish;
    end

endmodule