`default_nettype none
`timescale 1ns/1ns
`include "src/instr_dcd.v" // Assuming the file is named this

module tb_instr_dcd;

    // --- Signal Declarations ---
    reg clk;
    reg rst_n;
    
    // SPI Interface Signals
    reg byte_sync;
    reg [7:0] data_in;      // Data FROM SPI (Command or Write Data)
    wire [7:0] data_out;    // Data TO SPI (Read Data)

    // Register Interface Signals
    wire read;
    wire write;
    wire [5:0] addr;
    wire [7:0] data_write;  // Data written to register
    reg [7:0] data_read;    // Data read from register

    // --- DUT Instantiation ---
    instr_dcd DUT (
        .clk(clk),
        .rst_n(rst_n),
        .byte_sync(byte_sync),
        .data_in(data_in),
        .data_out(data_out),
        .read(read),
        .write(write),
        .addr(addr),
        .data_read(data_read),
        .data_write(data_write)
    );

    // --- Clock Generation ---
    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Tasks ---

    task apply_reset;
    begin
        rst_n = 0;
        byte_sync = 0;
        data_in = 0;
        data_read = 0;
        #20;
        rst_n = 1;
        @(posedge clk);
    end
    endtask

    // Task to send the Command Byte (First Byte)
    // Structure: [7]=RW, [6]=Hi/Lo, [5:0]=Addr
    task send_command;
        input is_write;
        input is_hi; // This bit also controls if ADDR is output on the bus
        input [5:0] address;
        reg [7:0] cmd;
        begin
            cmd = {is_write, is_hi, address};
            
            @(posedge clk);
            data_in = cmd;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;
            // Wait for logic to settle
            #1; 
            
            $display("[CMD] Sent 0x%h (RW=%b, Hi/Lo=%b, Addr=0x%h)", cmd, is_write, is_hi, address);
        end
    endtask

    // Task to perform a WRITE Data phase (After command is set)
    task perform_write_data;
        input [7:0] val_to_write;
        begin
            @(posedge clk);
            data_in = val_to_write;
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;
            #1; // Wait for logic

            // Verify
            if (write === 1'b1 && data_write === val_to_write) begin
                 $display("[PASS] Write Data: 0x%h correctly output on 'data_write'", val_to_write);
            end else begin
                 $display("[FAIL] Write Data: Expected 0x%h, Got 0x%h. Write_En=%b", val_to_write, data_write, write);
            end
        end
    endtask

    // Task to perform a READ Data phase
    task perform_read_data;
        input [7:0] val_from_register;
        begin
            // Setup the register data BEFORE the sync pulse
            data_read = val_from_register;
            
            @(posedge clk);
            // Pulse sync to latch data_read into internal_buffer
            byte_sync = 1;
            @(posedge clk);
            byte_sync = 0;
            
            // The DUT latches 'data_read' into 'internal_buffer' on the clock edge.
            // 'data_out' is assigned 'internal_buffer'.
            #1; 

            if (read === 1'b1 && data_out === val_from_register) begin
                $display("[PASS] Read Data: 0x%h correctly captured and output on 'data_out'", val_from_register);
            end else begin
                $display("[FAIL] Read Data: Expected 0x%h, Got 0x%h. Read_En=%b", val_from_register, data_out, read);
            end
        end
    endtask

    // Task to verify Address and Control Signals
    task check_status;
        input exp_write;
        input exp_read;
        input [5:0] exp_addr;
        begin
            #1;
            if (write === exp_write && read === exp_read && addr === exp_addr) begin
                $display("[PASS] Status: Write=%b, Read=%b, Addr=0x%h", write, read, addr);
            end else begin
                $display("[FAIL] Status: Expected W=%b R=%b A=0x%h | Got W=%b R=%b A=0x%h", 
                    exp_write, exp_read, exp_addr, write, read, addr);
            end
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        $dumpfile("build/instr_dcd_tb.vcd");
        $dumpvars(0, tb_instr_dcd);
        
        clk = 0;
        $display("--- Starting Instruction Decoder Simulation ---");

        // ---------------------------------------------------------
        // Test 1: Write Transaction (High Flag = 1)
        // High Flag=1 means Address SHOULD be visible
        // ---------------------------------------------------------
        $display("\nTest 1: Write to Address 0x0F (High Flag Set)");
        apply_reset();
        
        // Command: Write=1, Hi=1, Addr=0x0F
        send_command(1'b1, 1'b1, 6'h0F);
        
        // Check signals immediately after command
        // Note: internal_state updates, but 'send_data' is 0 until first data sync?
        // Actually, send_data is 0 initially.
        check_status(1'b1, 1'b0, 6'h0F);

        // Send Data 0xAA
        perform_write_data(8'hAA);


        // ---------------------------------------------------------
        // Test 2: Read Transaction (High Flag = 1)
        // ---------------------------------------------------------
        $display("\nTest 2: Read from Address 0x2A (High Flag Set)");
        apply_reset(); // Essential because DUT state machine doesn't auto-reset

        // Command: Write=0, Hi=1, Addr=0x2A
        send_command(1'b0, 1'b1, 6'h2A);
        
        check_status(1'b0, 1'b1, 6'h2A);

        // Simulate Register providing 0xCC
        perform_read_data(8'hCC);


        // ---------------------------------------------------------
        // Test 3: Write Transaction (High Flag = 0)
        // *** CRITICAL DUT BEHAVIOR CHECK ***
        // Your logic: assign addr = (internal_state[0]) ? address : 6'd0;
        // Since Hi=0, internal_state[0] is 0.
        // We expect ADDR output to be 0, regardless of command address.
        // ---------------------------------------------------------
        $display("\nTest 3: Write to Address 0x3F with Low Flag (Addr Mask Check)");
        apply_reset();

        // Command: Write=1, Hi=0, Addr=0x3F
        send_command(1'b1, 1'b0, 6'h3F);

        // Expect: Write=1, Read=0, ADDR=0 (Because Hi flag is 0)
        check_status(1'b1, 1'b0, 6'h00);

        perform_write_data(8'h55);

        $display("\n--- Simulation Complete ---");
        $finish;
    end

endmodule