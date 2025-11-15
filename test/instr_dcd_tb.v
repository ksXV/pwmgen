`default_nettype none
`include "src/instr_dcd.v"
`timescale 1ns/1ns

module tb_instr_dcd;
reg clk = 1'b1;
reg rst_n = 1'b1;
reg byte_sync = 1'b0;
reg [7:0] data_in = 8'b0;
reg [7:0] data_read = 8'b0;

wire [7:0] data_out;
wire read;
wire write;
wire [5:0] addr;
wire [7:0] data_write;

instr_dcd DUT
(
    .rst_n (rst_n),
    .clk (clk),
    .byte_sync(byte_sync),
    .data_in(data_in),
    .data_out(data_out),
    .read(read),
    .write(write),
    .addr(addr),
    .data_read(data_read),
    .data_write(data_write)
);

localparam CLK_PERIOD = 2;
always #(CLK_PERIOD/2) clk=~clk;

initial begin
    $dumpfile("build/instr_dcd_tb.vcd");
    $dumpvars(0, tb_instr_dcd);
end

initial begin
    #10;
    data_in = 8'b01001111;
    byte_sync = 1'b1;
    #2;
    byte_sync = 1'b0;
    data_in = 8'b0;
    #5; // do nothing
    data_read = 8'hff;
    byte_sync = 1'b1;
    #3;
    byte_sync = 1'b0;
    rst_n = 1'b0;
    #5;
    rst_n = 1'b1;
    data_in = 8'b10001111;
    byte_sync = 1'b1;
    #1;
    byte_sync = 1'b0;
    #5;
    data_in = 8'hab;
    byte_sync = 1'b1;

    #2;
    byte_sync = 1'b0;

    #2;

    $finish(2);
end

endmodule
`default_nettype wire