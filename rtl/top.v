// =============================================================
// top.v  ―― 全部を束ねるトップモジュール
//   ① クロックを用意（実機ではPLLで25MHz、ここでは簡略化）
//   ② vga_640x480 を1個置いて x/y/visible/同期 を得る
//   ③ draw_test に x/y を渡して色(r,g,b)を作る
//   ④ r/g/b/hsync/vsync を外部ピン(抵抗DAC, VGAコネクタ)へ
//
//   ※ vga_r/g/b は各2bit。実機ではこれを抵抗DACに通して
//      アナログ0.7Vにしてからコネクタの1/2/3番ピンへ。
// =============================================================
module top (
    input  wire       clk_in,    // ボードの水晶 (実機では27MHz等→PLLで25MHzへ)
    output wire       hsync,     // VGA 13番ピン
    output wire       vsync,     // VGA 14番ピン
    output wire [1:0] vga_r,     // → 抵抗DAC → VGA 1番ピン
    output wire [1:0] vga_g,     // → 抵抗DAC → VGA 2番ピン
    output wire [1:0] vga_b      // → 抵抗DAC → VGA 3番ピン
);
    // ① ピクセルクロック
    //   実機: PLLで25MHz付近を生成して pix_clk に入れる。
    //   例)  my_pll pll0(.clkin(clk_in), .clkout(pix_clk));
    //   ここではシミュレーション簡略化のため clk_in をそのまま使う。
    wire pix_clk = clk_in;

    // ② タイミング土台
    wire       visible;
    wire [9:0] x, y;
    vga_640x480 vga0 (
        .pix_clk (pix_clk),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible),
        .x       (x),
        .y       (y)
    );

    // フレーム先頭(左上の最初のピクセル)で1パルス → アニメ更新用
    wire frame_tick = (x == 10'd0) && (y == 10'd0);

    // ③ 描画
    draw_test draw0 (
        .clk        (pix_clk),
        .visible    (visible),
        .x          (x),
        .y          (y),
        .frame_tick (frame_tick),
        .r          (vga_r),
        .g          (vga_g),
        .b          (vga_b)
    );
endmodule
