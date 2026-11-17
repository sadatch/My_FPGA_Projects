// tick_gen.sv -- DIV クロックごとに 1 クロックのパルスを出す
//   100 MHz / 25000 = 4 kHz  (dt = 0.25 ms の実時間)
module tick_gen #(
    parameter int DIV = 25000
) (
    input  logic clk,
    input  logic rst,
    output logic tick
);
    logic [31:0] cnt;
    always_ff @(posedge clk) begin
        tick <= 1'b0;
        if (rst) cnt <= 32'd0;
        else if (cnt == DIV - 1) begin
            cnt  <= 32'd0;
            tick <= 1'b1;
        end else cnt <= cnt + 32'd1;
    end
endmodule
