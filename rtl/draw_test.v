// =============================================================
// draw_test.v  ―― 実際に絵を描く部分（ここを自由に書き換える）
//   入力: x, y (座標), visible, frame_tick (1フレーム1パルス)
//   出力: r, g, b  各2bit (= 0..3, 64色)
//
//   描くもの（雑なテスト柄）:
//     1) 背景    : 縦8本のカラーバー (x座標で色を変える)
//     2) 外枠    : 画面のフチに白い枠
//     3) 動く箱  : 64x64の白い箱が画面内をバウンドする
//   優先順位は「箱 > 枠 > カラーバー」。
// =============================================================
module draw_test (
    input  wire       clk,         // pix_clk
    input  wire       visible,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       frame_tick,  // フレームの先頭で1パルス
    output reg  [1:0] r,
    output reg  [1:0] g,
    output reg  [1:0] b
);
    localparam BOX = 64;     // 箱の一辺
    localparam SPD = 2;      // 1フレームで動く量(px)

    // ---- アニメーション: 箱の位置を毎フレーム更新（順序回路）----
    reg [9:0] box_x = 100;
    reg [9:0] box_y = 100;
    reg       dx = 1'b1;     // 1:右へ 0:左へ
    reg       dy = 1'b1;     // 1:下へ 0:上へ

    always @(posedge clk) begin
        if (frame_tick) begin
            // 横方向：右端/左端で跳ね返す
            if (dx) begin
                if (box_x + BOX >= 640 - SPD) dx <= 1'b0;
                else                          box_x <= box_x + SPD;
            end else begin
                if (box_x <= SPD)             dx <= 1'b1;
                else                          box_x <= box_x - SPD;
            end
            // 縦方向：上端/下端で跳ね返す
            if (dy) begin
                if (box_y + BOX >= 480 - SPD) dy <= 1'b0;
                else                          box_y <= box_y + SPD;
            end else begin
                if (box_y <= SPD)             dy <= 1'b1;
                else                          box_y <= box_y - SPD;
            end
        end
    end

    // ---- 各ピクセルがどの図形に当たるか（組み合わせ回路）----
    wire in_box = (x >= box_x) && (x < box_x + BOX) &&
                  (y >= box_y) && (y < box_y + BOX);

    wire border = (x < 2) || (x >= 640 - 2) || (y < 2) || (y >= 480 - 2);

    // 64px幅のカラーバー。x[8:6] が 0..7 のバー番号になる
    wire [2:0] bar = x[8:6];
    reg  [1:0] cr, cg, cb;
    always @(*) begin
        case (bar)
            3'd0: {cr,cg,cb} = {2'b11, 2'b11, 2'b11}; // 白
            3'd1: {cr,cg,cb} = {2'b11, 2'b11, 2'b00}; // 黄
            3'd2: {cr,cg,cb} = {2'b00, 2'b11, 2'b11}; // シアン
            3'd3: {cr,cg,cb} = {2'b00, 2'b11, 2'b00}; // 緑
            3'd4: {cr,cg,cb} = {2'b11, 2'b00, 2'b11}; // マゼンタ
            3'd5: {cr,cg,cb} = {2'b11, 2'b00, 2'b00}; // 赤
            3'd6: {cr,cg,cb} = {2'b00, 2'b00, 2'b11}; // 青
            default:{cr,cg,cb} = {2'b00, 2'b00, 2'b00}; // 黒
        endcase
    end

    // ---- 最終的な色を決める（優先順位つき）----
    always @(*) begin
        if (!visible) begin
            {r,g,b} = 6'b000000;                 // 表示領域外は必ず黒
        end else if (in_box) begin
            {r,g,b} = {2'b11, 2'b11, 2'b11};     // 箱 = 白
        end else if (border) begin
            {r,g,b} = {2'b11, 2'b11, 2'b11};     // 枠 = 白
        end else begin
            {r,g,b} = {cr, cg, cb};              // 背景 = カラーバー
        end
    end
endmodule
