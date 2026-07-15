module clk_div25(
    input wire clk_in,   // 100MHz
    output wire clk_out  // 25MHz
);
    reg [1:0] cnt = 0;
    always @(posedge clk_in) begin
        cnt <= cnt + 1'b1;
    end
    assign clk_out = cnt[1];
endmodule