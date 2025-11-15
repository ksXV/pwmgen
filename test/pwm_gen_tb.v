`default_nettype none
`include "src/pwm_gen.v"
`timescale 1ns/1ns

module tb_pwm_gen;
reg clk = 1'b1;
reg rst_n = 1'b1;
reg pwm_en = 1'b0;
reg [15:0] period;
reg [7:0] functions;
reg [15:0] compare1;
reg [15:0] compare2;
reg [15:0] count_val;


reg cnt_en = 1'b0;

wire pwm_out;

pwm_gen DUT 
(
    .rst_n (rst_n),
    .clk (clk),
    .pwm_en(pwm_en),
    .period(period),
    .functions(functions),
    .compare1(compare1),
    .compare2(compare2),
    .count_val(count_val),
    .pwm_out(pwm_out)
);

localparam CLK_PERIOD = 10;
localparam FUNCTION_ALIGN_LEFT = 2'b00;
localparam FUNCTION_ALIGN_RIGHT = 2'b01;
localparam FUNCTION_RANGE_BETWEEN_COMPARES = 2'b10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count_val <= 16'd0;
    end else if (cnt_en) begin
        if (count_val+1 == period) begin
            count_val <= 16'd0; // Reset
        end else begin
            count_val <= count_val + 1'b1; // Increment
        end
    end
end

always #(CLK_PERIOD/2) clk=~clk;

initial begin
    $dumpfile("build/pwm_gen_tb.vcd");
    $dumpvars(0, tb_pwm_gen);
end

// --- Test Sequence ---
initial begin
    // --- 1. Initial Setup and Reset ---
    rst_n = 1'b0;
    pwm_en = 1'b0;
    period = 16'd9;     // Count from 0 to 9 (10 clock cycles total period)
    compare1 = 16'd3;   // Will be used for a 40% duty cycle (4 cycles high)
    compare2 = 16'd7;
    count_val = 16'hfffe; 
    
    $display("--- Starting Testbench ---");

    // Hold reset for a few cycles
    repeat(5) #(CLK_PERIOD);
    rst_n = 1'b1;
    #(CLK_PERIOD)
    $display("Reset de-asserted.");

    // --- 2. Test FUNCTION_ALIGN_LEFT (Positive/Leading Edge PWM) ---
    // Pulse starts HIGH at count=0, goes LOW at compare1=3 (Duty Cycle: (3+1)/10 = 40%)
    $display("--- Test Case 1: FUNCTION_ALIGN_LEFT (40%% Duty Cycle) ---");
    pwm_en = 1'b1;
    functions = FUNCTION_ALIGN_LEFT; 
    compare1 = 16'd3; 
    count_val = 16'd0; 
    cnt_en = 1'b1;
    
    // Run for 3 full periods (30 cycles)
    repeat(30) #(CLK_PERIOD);
    
    // --- 3. Test FUNCTION_ALIGN_RIGHT (Negative/Trailing Edge PWM) ---
    // Pulse starts LOW at count=0, goes HIGH at count=period-compare1, goes LOW at count=period
    // *NOTE*: Your current right-aligned logic in the DUT:
    // It starts LOW, goes HIGH at `compare1` and back LOW at `period` (Duty Cycle: (period - compare1)/period).
    // Let's test based on the DUT's logic: period=9, compare1=3 -> Duty Cycle: (9-3)/10 = 60% (counts 4,5,6,7,8,9 high)
    $display("--- Test Case 2: FUNCTION_ALIGN_RIGHT (60%% Duty Cycle) ---");
    functions = FUNCTION_ALIGN_RIGHT; 
    compare1 = 16'd3; 
    
    // Run for 3 full periods (30 cycles)
    repeat(30) #(CLK_PERIOD);

    // --- 4. Test FUNCTION_RANGE_BETWEEN_COMPARES ---
    // *NOTE*: You need to complete the logic for this mode in the DUT!
    // Assuming the intent is for the output to be HIGH when count_val >= compare1 AND count_val < compare2.
    // period=9, compare1=3, compare2=7 -> HIGH for counts 3, 4, 5, 6 (40% Duty Cycle)
    $display("--- Test Case 3: FUNCTION_RANGE_BETWEEN_COMPARES (40%% Duty Cycle) ---");
    functions = FUNCTION_RANGE_BETWEEN_COMPARES;
    compare1 = 16'd3;
    compare2 = 16'd7;

    // Run for 3 full periods (30 cycles)
    repeat(30) #(CLK_PERIOD);
    
    // --- 5. Clean up and finish ---
    pwm_en = 1'b0;
    #(CLK_PERIOD);
    $display("--- Testbench Finished. ---");
    $finish;
end

endmodule
`default_nettype wire