//TODO: avem nevoie de inca un fir ca sa ne dam seama in ce sectiune sa scriem data_write
module regs (
    // peripheral clock signals
    input clk,
    input rst_n,
    // decoder facing signals
    input read,
    input write,
    input[5:0] addr,
    output[7:0] data_read,
    input[7:0] data_write,
    // counter programming signals
    input[15:0] counter_val,
    output[15:0] period,
    output en,
    output count_reset,
    output upnotdown,
    output[7:0] prescale,
    // PWM signal programming values
    output pwm_en,
    output[1:0] functions,
    output[15:0] compare1,
    output[15:0] compare2
);

localparam PERIOD_ADDRESS        = 6'h00;
localparam COUNTER_EN_ADDRESS    = 6'h02;
localparam COMPARE1_ADDRESS      = 6'h03;
localparam COMPARE2_ADDRESS      = 6'h05;
localparam COUNTER_RESET_ADDRESS = 6'h07;
localparam COUNTER_VAL_ADDRESS   = 6'h08;
localparam PRESCALE_ADDRESS      = 6'h0A;
localparam UPNOTDOWN_ADDRESS     = 6'h0B;
localparam PWM_EN_ADDRESS        = 6'h0C;
localparam FUNCTIONS_ADDRESS     = 6'h0D;

/*
    All registers that appear in this block should be similar to this. Please try to abide
    to sizes as specified in the architecture documentation.
*/
reg [15:0] period_reg = 16'd0;
reg counter_en_reg = 1'b0;
reg [15:0] compare1_reg = 16'd0;
reg [15:0] compare2_reg = 16'd0;
reg counter_reset_reg = 1'b0;
reg [15:0] counter_val_reg = 16'd0;
reg [7:0] prescale_reg = 8'd0;
reg upnotdown_reg = 1'b0;
reg pwm_en_reg = 1'b0;
reg [1:0] functions_reg = 2'b0;

reg [7:0] buffer_for_reading = 8'd0;

reg reset_delay_counter = 1'b0;

reg hold_counter_val = 1'b0;
reg [3:0] count_cycles = 4'd0;

assign data_read = (read) ? buffer_for_reading : 8'b0;

assign period = period_reg;
assign en = counter_en_reg;
assign count_reset = counter_reset_reg;
assign upnotdown = upnotdown_reg;
assign prescale = prescale_reg;
assign pwm_en = pwm_en_reg;
assign functions = functions_reg;
assign compare1 = compare1_reg;
assign compare2 = compare2_reg;


always @(*) begin
        if (read) begin 
            if (addr == COUNTER_VAL_ADDRESS) begin
                if (!hold_counter_val) begin
                    counter_val_reg[7:0] = counter_val[7:0];
                    hold_counter_val = 1'b1;
                end else begin
                    if (count_cycles == 4'd8) begin
                        hold_counter_val = 1'b0;
                    end else begin
                        hold_counter_val = 1'b1;
                    end
                end
            end else begin
            hold_counter_val = 1'b0;
            counter_val_reg[7:0] = counter_val[7:0];
            end
        end else begin
            hold_counter_val = 1'b0;
            counter_val_reg[7:0] = counter_val[7:0];
        end
end




//TODO: avem nevoie de inca un fir ca sa ne dam seama in ce sectiune sa scriem data_write
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        period_reg <= 16'h0000;
        counter_en_reg <= 1'b0;
        compare1_reg <= 16'h0000;
        compare2_reg <= 16'h0000;
        counter_reset_reg <= 1'b0;
        prescale_reg <= 8'h00;
        upnotdown_reg <= 1'b0;
        pwm_en_reg <= 1'b0;
        functions_reg <= 2'b00;
        buffer_for_reading <= 8'h00;
    end
    else begin
        if (counter_reset_reg) begin
            if (reset_delay_counter) begin
                reset_delay_counter <= 1'b0;
                counter_reset_reg <= 1'b0;
            end else begin
                reset_delay_counter <= 1'b1;
            end
        end

        if (write) begin
            case (addr) 
                PERIOD_ADDRESS:
                    period_reg[7:0] <= data_write;
                COUNTER_EN_ADDRESS:
                    counter_en_reg <= data_write[0];
                COMPARE1_ADDRESS:
                    compare1_reg[7:0] <= data_write;
                COMPARE2_ADDRESS:
                    compare2_reg[7:0] <= data_write;
                COUNTER_RESET_ADDRESS:
                    counter_reset_reg <= data_write[0];
                PRESCALE_ADDRESS:
                    prescale_reg <= data_write;
                UPNOTDOWN_ADDRESS:
                    upnotdown_reg <= data_write[0];
                PWM_EN_ADDRESS:
                    pwm_en_reg <= data_write[0];
                FUNCTIONS_ADDRESS:
                    functions_reg <= data_write[1:0];
                default: /* do nothing */ ;
            endcase
        end 
        if (read) begin
            if (hold_counter_val) begin
                count_cycles <= count_cycles + 1;
            end
            case (addr) 
                PERIOD_ADDRESS: 
                    buffer_for_reading <= period_reg[7:0];
                COUNTER_EN_ADDRESS:
                    buffer_for_reading <= {7'b0, counter_en_reg};
                COMPARE1_ADDRESS:
                    buffer_for_reading <= compare1_reg[7:0];
                COMPARE2_ADDRESS:
                    buffer_for_reading <= compare2_reg[7:0];
                COUNTER_VAL_ADDRESS:
                    buffer_for_reading <= counter_val_reg[7:0];
                PRESCALE_ADDRESS:
                    buffer_for_reading <= prescale_reg;
                UPNOTDOWN_ADDRESS:
                    buffer_for_reading <= {7'b0, upnotdown_reg};
                PWM_EN_ADDRESS:   
                    buffer_for_reading <= {7'b0, pwm_en_reg};
                FUNCTIONS_ADDRESS:
                    buffer_for_reading <= {6'b0, functions_reg};
                default: /* do nothing */ ;
            endcase
        end
    end
end

endmodule