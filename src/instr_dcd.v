module instr_dcd (
    // peripheral clock signals
    input clk,
    input rst_n,
    // towards SPI slave interface signals
    input byte_sync,
    input[7:0] data_in,
    output[7:0] data_out,
    // register access signals
    output read,
    output write,
    output[5:0] addr,
    input[7:0] data_read,
    output[7:0] data_write
);

// READY_READ_HI inseamna ca a fost citit primul byte pt comunicare, 
// READ inseamna ca bitul 7 din primul byte este 0
// HI inseamna ca o sa scriem/citim in/din sectiunea [15:8] a registrului de la addresa 'addr'
localparam READY_READ_HI = 3'b101;
localparam READY_READ_LO = 3'b100;
localparam READY_WRITE_HI = 3'b111;
localparam READY_WRITE_LO = 3'b110;
localparam NEEDS_FIRST_BYTE = 3'b000;

// Trebuie sa codificam ce vrem sa facem
// Daca internal state este 0?? nu facem nimic (? inseamna ca nu ne pasa daca avem 0 sau 1)
// 1?? - am citit primul byte / daca bitul e 0 atunci nu am terminat de citit primul byte
// 11? - scriem ceva la address / daca bitul e 0 atunci o sa citim ce ne da 
//       "masterul" prin mosi
// 111 - read/write in/din sectiunea [15:8] dintr-un registru??? / daca bitul e zero atunci 
//       scriem/citim din/in sectiunea [7:0] a registrului respectiv
reg [2:0] internal_state = NEEDS_FIRST_BYTE;
reg [5:0] address = 6'b00000;
reg [7:0] internal_buffer = 8'd0;
reg send_data = 1'b0;

assign write = (internal_state[2]) ? internal_state[1] : read;
assign read = (internal_state[2]) ? ~write : 0;

assign data_write = (write && send_data) ? internal_buffer : 8'hf0;
assign data_out = (read && send_data) ? internal_buffer : 8'd0;

assign addr = (internal_state[0]) ? address : 6'd0;

always @(negedge rst_n) begin
    if (!rst_n) begin
        internal_state <= 3'd0;
        address <= 6'd0;
        internal_buffer <= 8'd0;
        send_data <= 1'b0;
    end
end


// verilator lint_off LATCH
always @(*) begin
    if (byte_sync) begin
        // incepem sa citim primul byte asa ca 
        // il decodam in internal state
        case (internal_state) 
            NEEDS_FIRST_BYTE: begin
                internal_state[2] = 1'b1;
                internal_state[1] = data_in[7];
                internal_state[0] = data_in[6];
                address[5:0] = data_in[5:0];
            end
            READY_WRITE_HI: begin
                send_data = 1'b1;
                internal_buffer = data_in;
            end
            READY_WRITE_LO: begin
                send_data = 1'b1;
                internal_buffer = data_in;
                //needs to set a flag for the lower or higher position
            end
            READY_READ_HI: begin
                send_data = 1'b1;
                internal_buffer = data_read;
            end
            READY_READ_LO: begin
                send_data = 1'b1;
                internal_buffer = data_read;
            end
            default:; // do nothing
        endcase
    end
end
// verilator lint_on LATCH

endmodule