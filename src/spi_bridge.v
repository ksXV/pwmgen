`default_nettype none

module spi_bridge (
    // peripheral clock signals
    input clk,
    input rst_n,
    // SPI master facing signals
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // internal facing 
    output byte_sync,
    output[7:0] data_in,
    input[7:0] data_out
);

localparam IS_FULL = 4'd8;

reg [3:0] bits_read = 4'd0;
reg [2:0] bits_written = 3'd0;
reg [7:0] byte_buffer = 8'd0;

reg is_read  = 1'b0;
reg is_write = 1'b0;
reg was_first_byte_read = 1'b0;

assign byte_sync = (bits_read == IS_FULL) ? 1'b1 : 1'b0;
assign data_in = (bits_read == IS_FULL) ? byte_buffer : 8'd0;
assign miso = (was_first_byte_read && is_write) ? data_out[bits_written] : 1'b0;

always @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
        byte_buffer <= 8'd0;
        bits_read <= 4'd0;
        byte_buffer <= 8'd0;
        is_read <= 1'b0;
        is_write <= 1'b0;
        was_first_byte_read <= 1'b0;
        bits_written <= 3'd0;
    end else begin
        if (!cs_n) begin
            if (!was_first_byte_read) begin
                // Folosim un "shift register" ca sa citim in buffer
                byte_buffer <= byte_buffer << 1;
                byte_buffer[0] <= mosi;
                if (bits_read != IS_FULL) bits_read <= bits_read + 1;
                else bits_read <= 1;
            end else begin
                if (is_read) begin
                    byte_buffer <= byte_buffer << 1;
                    byte_buffer[0] <= mosi;
                    if (bits_read != IS_FULL) bits_read <= bits_read + 1;
                    else bits_read <= 1;
                end
                else if (is_write) begin
                    if (bits_read == IS_FULL) bits_read <= 0;

                    if ( ({1'b0, bits_written}) != (IS_FULL-1)) bits_written <= bits_written + 1;
                    else bits_written <= 0;
                end
            end
        end
    end
end

// verilator lint_off LATCH
always @(*) begin
    if ((bits_read == IS_FULL) && (was_first_byte_read == 1'b0)) begin
        was_first_byte_read = 1'b1;
        is_write = byte_buffer[7];
        is_read = ~is_write;
    end
end
// verilator lint_off LATCH


endmodule