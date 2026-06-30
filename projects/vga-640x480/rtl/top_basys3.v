// =============================================================
// top_basys3.v  ―― Basys3 (Artix-7) 実機用トップモジュール
//   ・クロック: 基板の 100MHz を ÷4 して 25MHz ピクセルクロックに
//   ・色      : 基板のVGAは各色4bit。draw_test の2bitを4bitへ拡張
//   ・DAC     : Basys3 は基板にVGA用抵抗DAC内蔵 → 自作DAC不要
//   合成時はこのモジュールを top に設定し、Basys3_VGA.xdc を使う。
//   （シミュレーションは従来どおり top.v + tb_vga_test.v を使用）
// =============================================================
module top_basys3 (
    input  wire       clk,        // 100MHz 基板クロック (W5)
    output wire       Hsync,      // P19
    output wire       Vsync,      // R19
    output wire [3:0] vgaRed,     // G19,H19,J19,N19
    output wire [3:0] vgaGreen,   // J17,H17,G17,D17
    output wire [3:0] vgaBlue     // N18,L18,K18,J18
);
    // --- 100MHz → 25MHz ピクセルクロック (÷4) ---
    // 簡易版: 2bitカウンタの最上位ビットが 25MHz になる。
    // ※より厳密にやるなら Clocking Wizard(MMCM) で 25.175MHz を作る。
    reg [1:0] clkdiv = 2'b00;
    always @(posedge clk) clkdiv <= clkdiv + 1'b1;
    wire pix_clk = clkdiv[1];

    // --- タイミング土台（ボード非依存・共通） ---
    wire        visible;
    wire [9:0]  x, y;
    vga_640x480 vga0 (
        .pix_clk (pix_clk),
        .hsync   (Hsync),
        .vsync   (Vsync),
        .visible (visible),
        .x       (x),
        .y       (y)
    );

    // フレーム先頭で1パルス（アニメ更新用）
    wire frame_tick = (x == 10'd0) && (y == 10'd0);

    // --- 描画（ボード非依存・共通） 各色2bit ---
    wire [1:0] r2, g2, b2;
    draw_test draw0 (
        .clk        (pix_clk),
        .visible    (visible),
        .x          (x),
        .y          (y),
        .frame_tick (frame_tick),
        .r          (r2),
        .g          (g2),
        .b          (b2)
    );

    // --- 2bit → 4bit へ拡張して基板の4bit DACへ ---
    // 上位に複製: 00→0000, 01→0101, 10→1010, 11→1111（明るさが自然に伸びる）
    assign vgaRed   = {r2, r2};
    assign vgaGreen = {g2, g2};
    assign vgaBlue  = {b2, b2};
endmodule
