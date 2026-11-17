// bin2bcd.sv -- 2進 -> BCD (double dabble, 逐次)。14bit -> 4桁 (0..9999)
//   start を 1 クロック与えると 14 クロックほどで done が立ち、bcd が確定する。
module bin2bcd (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [13:0] bin,
    output logic [15:0] bcd,
    output logic        done
);
    logic [13:0] sh;
    logic [15:0] acc;
    logic [3:0]  cnt;
    logic        busy;

    // 各桁が 5 以上なら 3 を足してからシフト
    wire [3:0] n0 = (acc[3:0]   >= 4'd5) ? acc[3:0]   + 4'd3 : acc[3:0];
    wire [3:0] n1 = (acc[7:4]   >= 4'd5) ? acc[7:4]   + 4'd3 : acc[7:4];
    wire [3:0] n2 = (acc[11:8]  >= 4'd5) ? acc[11:8]  + 4'd3 : acc[11:8];
    wire [3:0] n3 = (acc[15:12] >= 4'd5) ? acc[15:12] + 4'd3 : acc[15:12];
    wire [15:0] shifted = {n3, n2, n1, n0} << 1 | {15'd0, sh[13]};

    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (rst) busy <= 1'b0;
        else if (start && !busy) begin
            sh   <= bin;
            acc  <= 16'd0;
            cnt  <= 4'd0;
            busy <= 1'b1;
        end else if (busy) begin
            acc <= shifted;
            sh  <= {sh[12:0], 1'b0};
            cnt <= cnt + 4'd1;
            if (cnt == 4'd13) begin
                busy <= 1'b0;
                done <= 1'b1;
                bcd  <= shifted;
            end
        end
    end
endmodule
