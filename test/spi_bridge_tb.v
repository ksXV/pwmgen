`default_nettype none
`include "src/spi_bridge.v"
`timescale 1ns/1ns

module tb_spi_bridge;
reg s_clk = 1'b1;
reg rst_n = 1'b1;

reg cs_n = 1'b1;
reg mosi = 1'bx;
reg [7:0] data_out;

wire clk = 1'b0;
wire miso;
wire byte_sync;
wire [7:0] data_in;

spi_bridge DUT
(
    .rst_n (rst_n),
    .clk (clk),

    .sclk (s_clk),
    .cs_n (cs_n),
    .mosi (mosi),
    .miso (miso),

    .byte_sync(byte_sync),
    .data_in(data_in),
    .data_out(data_out)
);

localparam CLK_PERIOD = 2;
always #(CLK_PERIOD/2) s_clk=~s_clk;

initial begin
    $dumpfile("build/spi_bridge_tb.vcd");
    $dumpvars(0, tb_spi_bridge);
end

initial begin
    //Nothing funny should happen;
    #10;

    //start transmission at time 10
    cs_n = 0;
    mosi = 1;

    #1; //time 1
    mosi = 0; //time 2
    #5; //time 7
    mosi = 1;
    #2;
    mosi = 0;
    #3;
    mosi = 1;
    #6;

    cs_n = 1;

    #10;
    cs_n = 0;
    data_out = 8'hfa;
    #17;

    cs_n = 1;
    rst_n = 0;

    #2;
    rst_n = 1;
    #1;

    $finish;
end

endmodule
`default_nettype wire