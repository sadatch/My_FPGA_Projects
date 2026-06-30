// =============================================================
// vga_640x480.v  ―― タイミング生成の「土台」モジュール
//   これは一度書いたら基本いじらない再利用パーツ。
//   役割: pix_clk を数えて「今どこを描いているか」を出すだけ。
//     - x, y      : 表示領域内の座標 (0..639, 0..479)
//     - visible   : いま表示領域の中か (色を出していいか)
//     - hsync/vsync: モニタへの同期信号 (負論理)
// =============================================================
module vga_640x480 (
    input  wire       pix_clk,   // 25MHz付近のピクセルクロック
    output wire       hsync,
    output wire       vsync,
    output wire       visible,
    output wire [9:0] x,
    output wire [9:0] y
);
    // 640x480 60Hz 標準タイミング
    localparam H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
    localparam V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33, V_TOTAL = 525;

    reg [9:0] h_count = 0;   // 0..799
    reg [9:0] v_count = 0;   // 0..524

    always @(posedge pix_clk) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1) v_count <= 0;
            else                        v_count <= v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    assign visible = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    assign x = h_count;
    assign y = v_count;

    // 負論理: Sync pulse の期間だけ Low
    assign hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                     (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                     (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
endmodule
