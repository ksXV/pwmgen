module pwm_gen (
    // peripheral clock signals
    input clk,
    input rst_n,
    // PWM signal register configuration
    input pwm_en,
    input[15:0] period,
    input[7:0] functions,
    input[15:0] compare1,
    input[15:0] compare2,
    input[15:0] count_val,
    // top facing signals
    output pwm_out
);

localparam FUNCTION_ALIGN_LEFT = 2'b00;
localparam FUNCTION_ALIGN_RIGHT = 2'b01;
localparam FUNCTION_RANGE_BETWEEN_COMPARES = 2'b10;

reg internal_pwm = 1'bx;
reg is_counter_about_to_reset = 1'b0;

assign pwm_out = internal_pwm;

always @(functions) begin
    internal_pwm = (functions[1]) ? (compare1 == count_val) : ~functions[0];
    is_counter_about_to_reset = 1'b0;
end

always @(count_val) begin
    if ((count_val + 1) == period) is_counter_about_to_reset = 1'b1;
    case (functions) 
        FUNCTION_ALIGN_LEFT: if (!is_counter_about_to_reset) internal_pwm = (compare1 > count_val);
        FUNCTION_ALIGN_RIGHT: if (!is_counter_about_to_reset) internal_pwm = (count_val > compare1);
        FUNCTION_RANGE_BETWEEN_COMPARES: if (!is_counter_about_to_reset) internal_pwm = (count_val >= compare1 && count_val < compare2);
        default:;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        internal_pwm <= 1'b0;
        is_counter_about_to_reset <= 1'b0;
    end else begin
        if (pwm_en) begin
            case (functions) 
                FUNCTION_ALIGN_LEFT: begin
                    if (is_counter_about_to_reset) begin
                        internal_pwm <= 1'b1;
                        is_counter_about_to_reset <= 1'b0;
                    end
                end
                FUNCTION_ALIGN_RIGHT: begin
                    if (is_counter_about_to_reset) begin
                        internal_pwm <= 1'b0;
                        is_counter_about_to_reset <= 1'b0;
                    end
                end
                FUNCTION_RANGE_BETWEEN_COMPARES: begin 
                    if (is_counter_about_to_reset) 
                        is_counter_about_to_reset <= 1'b0;
                end
                default:; // do nothing
            endcase
        end
    end
end

endmodule