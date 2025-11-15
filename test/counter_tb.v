`default_nettype none
`include "src/counter.v"
`timescale 1ns/1ns
module tb_counter;

// Constants for timing
parameter CLK_PERIOD = 10; // 10ns clock period

// Signals for the counter module interface
reg clk;
reg rst_n;
reg [15:0] period;
reg en;
reg count_reset;
reg upnotdown;
reg [7:0] prescale;

wire [15:0] count_val;

// Instantiate the Device Under Test (DUT)
counter DUT (
    .clk(clk),
    .rst_n(rst_n),
    .count_val(count_val),
    .period(period),
    .en(en),
    .count_reset(count_reset),
    .upnotdown(upnotdown),
    .prescale(prescale)
);

// Clock generation
initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
end

// Helper task to advance clock cycles
task clock_cycles;
    input integer num_cycles;
    integer i;
    begin
        for (i = 0; i < num_cycles; i = i + 1) begin
            #CLK_PERIOD;
        end
    end
endtask

initial begin
    $dumpfile("build/counter_tb.vcd");
    $dumpvars(0, tb_counter);
end

// Test sequence
initial begin
    $display("--- Starting Counter Module Testbench ---");

    // Initial Setup
    period = 16'd5;
    en = 0;
    count_reset = 0;
    upnotdown = 1; // Default to Up mode (though main counter always increments)
    prescale = 2;  // Prescale value of 2 means division by 2^2 = 4

    // 1. Initial Reset
    $display("Time %0d: Asserting Reset.", $time);
    rst_n = 0; // Assert Reset
    count_reset = 1; // Assert Count Reset (redundant but good practice)
    # (CLK_PERIOD * 2);
    
    // Deassert Reset and Count Reset
    rst_n = 1; 
    count_reset = 0; 
    
    // Counter should be 0 after reset
    #(CLK_PERIOD);
    if (count_val === 16'd0)
        $display("Time %0d: SUCCESS - Post-Reset count_val is 0.", $time);
    else
        $display("Time %0d: FAILED - Post-Reset count_val expected 0, got %d.", $time, count_val);

    // 2. Test Enable Latching and Prescale (prescale=2, divisor=4)
    $display("\n--- Test 2: Enable Latch and 4-cycle Prescale (Up Mode) ---");
    
    // Enable for 1 cycle, then turn off. The counter should still run.
    en = 1;
    #(CLK_PERIOD);

    // Wait 3 cycles (total 4 cycles from when enable was first latched)
    clock_cycles(3); 
    
    // Cycle 4: Count should increment (1 / 4th of the clock cycles)
    if (count_val === 16'd1)
        $display("Time %0d: SUCCESS - Count value reached 1 after 4 cycles (Prescale 2).", $time);
    else
        $display("Time %0d: FAILED - Count expected 1, got %d.", $time, count_val);

    // Wait 4 more cycles
    clock_cycles(4); 
    
    // Cycle 8: Count should increment again
    if (count_val === 16'd2)
        $display("Time %0d: SUCCESS - Count value reached 2 after 8 cycles.", $time);
    else
        $display("Time %0d: FAILED - Count expected 2, got %d.", $time, count_val);
        
    // 3. Test Period Rollover (Period=5)
    $display("\n--- Test 3: Period Rollover (Period=5) ---");
    // Current count_val is 2. Need 3 more increments to reach 5, then 1 more to rollover.

    // 2 -> 3
    clock_cycles(4); 
    $display("Time %0d: Count reached 3.", $time);

    // 3 -> 4
    clock_cycles(4); 
    $display("Time %0d: Count reached 4.", $time);

    // 4 -> 5 (Max period)
    clock_cycles(4); 
    if (count_val === 16'd5)
        $display("Time %0d: SUCCESS - Count reached Period max (5).", $time);
    else
        $display("Time %0d: FAILED - Count expected 5, got %d.", $time, count_val);

    // 5 -> 0 (Rollover)
    clock_cycles(4); 
    if (count_val === 16'd0)
        $display("Time %0d: SUCCESS - Count rolled over to 0.", $time);
    else
        $display("Time %0d: FAILED - Count expected 0 (rollover), got %d.", $time, count_val);


    // 4. Test Down Mode (`upnotdown = 0`)
    $display("\n--- Test 4: Down Mode Check (Prescale counter direction) ---");
    // Note: The main counter (count_val) still increments based on the DUT's logic.
    upnotdown = 0; 
    period = 16'd2;
    prescale = 1; // Division by 2^1 = 2
    
    // Need to reset the counter to apply new period/prescale effectively.
    count_reset = 1;
    #(CLK_PERIOD);
    count_reset = 0;
    
    if (count_val === 16'd0) $display("Time %0d: Reset complete.", $time);
    
    // 0 -> 1 (Takes 2 cycles in Down Mode, prescale=1)
    clock_cycles(2);
    if (count_val === 16'd1)
        $display("Time %0d: SUCCESS - Count reached 1 in Down Mode (Prescale 1).", $time);
    else
        $display("Time %0d: FAILED - Count expected 1, got %d.", $time, count_val);
        
    // 1 -> 2
    clock_cycles(2);
    if (count_val === 16'd2)
        $display("Time %0d: SUCCESS - Count reached 2.", $time);
    else
        $display("Time %0d: FAILED - Count expected 2, got %d.", $time, count_val);
        
    // 2 -> 0 (Rollover)
    clock_cycles(2);
    if (count_val === 16'd0)
        $display("Time %0d: SUCCESS - Count rolled over to 0.", $time);
    else
        $display("Time %0d: FAILED - Count expected 0 (rollover), got %d.", $time, count_val);

    $display("\n--- Finished Counter Module Testbench ---");
    $finish;
end

endmodule