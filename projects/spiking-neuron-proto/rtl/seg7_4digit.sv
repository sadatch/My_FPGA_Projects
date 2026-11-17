// seg7_4digit.sv -- Basys3 の 4 桁 7 セグに BCD(4桁) を表示（上位の 0 は消灯）
//   seg / an は負論理。an[0] が一番右の桁。
module seg7_4digit (
    input  logic        clk,          // 100MHz
    input  logic [15:0] bcd,
    output logic [6:0]  seg,          // {g,f,e,d,c,b,a}
    output logic [3:0]  an
);
    logic [18:0] div = 19'd0;
    always_ff @(posedge clk) div <= div + 19'd1;
    wire [1:0] sel = div[18:17];      // 1桁 ~1.3ms -> 全体 ~190Hz

    logic [3:0] digit;
    logic       blank;
    always_comb begin
        case (sel)
            2'd0: begin an = 4'b1110; digit = bcd[3:0];   blank = 1'b0; end
            2'd1: begin an = 4'b1101; digit = bcd[7:4];   blank = (bcd[15:4]  == 12'd0); end
            2'd2: begin an = 4'b1011; digit = bcd[11:8];  blank = (bcd[15:8]  == 8'd0);  end
            default: begin an = 4'b0111; digit = bcd[15:12]; blank = (bcd[15:12] == 4'd0); end
        endcase
    end

    always_comb begin
        if (blank) seg = 7'b1111111;
        else case (digit)
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
