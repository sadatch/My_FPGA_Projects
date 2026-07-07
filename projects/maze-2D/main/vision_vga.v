// =============================================================
// vga_640x480.v  ―― タイミング生成の「土台」モジュール
//   これは一度書いたら基本いじらない再利用パーツ。
//   役割: pix_clk を数えて「今どこを描いているか」を出すだけ。
//     - x, y      : 表示領域内の座標 (0..639, 0..479)
//     - visible   : いま表示領域の中か (色を出していいか)
//     - hsync/vsync: モニタへの同期信号 (負論理)
// =============================================================
module vga_640x480(
    input  wire pix_clk,
    output wire hsync,
    output wire vsync,
    output wire visible,
    output wire [9:0] x,
    output wire [9:0] y
);

    localparam H_visible = 640, H_front = 16, H_sync = 96, H_back = 48, H_total = 800;
    localparam V_visible = 480, V_front = 10, V_sync = 2,  V_back = 33, V_total = 525;

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge pix_clk) begin
        if (h_count == H_total - 1) begin
            h_count <= 0;
            if (v_count == V_total - 1) v_count <= 0;
            else                        v_count <= v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    assign visible = (h_count < H_visible) && (v_count < V_visible);
    assign x = h_count;
    assign y = v_count;

    assign hsync = ~((h_count >= H_visible + H_front) &&
                     (h_count < H_visible + H_front + H_sync));
    assign vsync = ~((v_count >= V_visible + V_front) &&
                     (v_count < V_visible + V_front + V_sync));
endmodule