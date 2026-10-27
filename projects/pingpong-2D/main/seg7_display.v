module seg7_display(
    input wire clk,
    input wire [3:0] scoreR,
    input wire [3:0] scoreL,

    output reg [6:0] seg,
    output reg [3:0] an
);
    //クロックの分周
    reg [19:0] clkdiv = 0;
    always @(posedge clk) begin
        clkdiv <= clkdiv + 1'b1;
    end
    wire [1:0] digit_sel = clkdiv [19:18];

    reg [3:0] current_digit;

    wire [3:0] right_player_point = scoreR;
    wire [3:0] left_player_point = scoreL;

    always @(*) begin
        case (digit_sel)
            2'b00: begin
                an = 4'b0111;
                current_digit = left_player_point;
            end
            2'b01: begin
                an = 4'b1101;
                current_digit = 4'hE;
            end
            2'b10: begin
                an = 4'b1011;
                current_digit = 4'hE;
            end
            2'b11: begin
                an = 4'b1110;
                current_digit = right_player_point;
            end
        endcase
    end

    always @(*) begin
        case(current_digit)
        4'd0: seg = 7'b1000000;
        4'd1: seg = 7'b1111001;
        4'd2: seg = 7'b0100100;
        4'd3: seg = 7'b0110000;
        4'd4: seg = 7'b0011001;
        4'd5: seg = 7'b0010010;
        4'd6: seg = 7'b0000010;
        4'd7: seg = 7'b1011000;
        4'd8: seg = 7'b0000000;
        4'd9: seg = 7'b0010000;
        default: seg = 7'b1111111;
        endcase
    end
endmodule