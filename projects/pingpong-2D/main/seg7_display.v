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

    assign right_player_point = scoreR;
    assign left_player_point = scoreL;

    always @(*) begin
        case (digit_sel)
            2'b00: begin
                an = 4'b1110;
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
                ab = 4'b1011;
                current_digit = right_player_point;
        endcase
endmodule