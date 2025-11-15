module counter (
    // peripheral clock signals
    input clk,
    input rst_n,
    // register facing signals
    output[15:0] count_val,
    input[15:0] period,
    input en,
    input count_reset,
    input upnotdown,
    input[7:0] prescale
);

reg [15:0] cnt = 16'd1;
reg [15:0] count_val_internal = 16'b0;

wire [15:0] prescale_cstn = (16'd1 << prescale);

assign count_val = count_val_internal;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n || count_reset) begin
        cnt <= 16'd1;
        count_val_internal <= 16'b0;
    end else begin
        if (en) begin
            if (upnotdown) begin
                if (cnt == prescale_cstn) begin
                    cnt <= 16'd1;
                    if (count_val_internal == period) 
                        count_val_internal <= 0;
                    else 
                        count_val_internal <= count_val_internal + 1;
                end
                else cnt <= cnt + 1;
            end else begin
                if (cnt == 1) begin 
                    cnt <= prescale_cstn;
                    if (count_val_internal == period) 
                        count_val_internal <= 0;
                    else 
                        count_val_internal <= count_val_internal + 1;
                end
                else cnt <= cnt - 1;
            end
        end
    end
end

endmodule