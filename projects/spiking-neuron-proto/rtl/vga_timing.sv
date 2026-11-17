// vga_timing.sv -- 640x480 @60Hz のタイミング生成（クロックイネーブル方式）
//   clk は 100MHz のまま、ce を 4 クロックに 1 回立てて 25MHz 相当で進める。
//   （カウンタの出力をクロックに使う方式は使わない: 単一クロック + イネーブルが定石）
module vga_timing (
    input  logic       clk,
    input  logic       ce,
    output logic [9:0] x,
    output logic [9:0] y,
    output logic       visible,
    output logic       hsync,       // 負論理
    output logic       vsync        // 負論理
);
    localparam int H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOT = 800;
    localparam int V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOT = 525;

    logic [9:0] xr = 10'd0;
    logic [9:0] yr = 10'd0;
    assign x = xr;
    assign y = yr;

    always_ff @(posedge clk) begin
        if (ce) begin
            if (xr == H_TOT - 1) begin
                xr <= 10'd0;
                yr <= (yr == V_TOT - 1) ? 10'd0 : yr + 10'd1;
            end else xr <= xr + 10'd1;
        end
    end

    assign visible = (x < H_VIS) && (y < V_VIS);
    assign hsync   = ~((x >= H_VIS + H_FP) && (x < H_VIS + H_FP + H_SYNC));
    assign vsync   = ~((y >= V_VIS + V_FP) && (y < V_VIS + V_FP + V_SYNC));
endmodule
