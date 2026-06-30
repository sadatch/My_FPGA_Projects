// =============================================================
// tb_vga_test.v  ―― シミュレーション用テストベンチ
//   pix_clk を回して top を動かし、表示領域のピクセルを
//   PPM画像(frame.ppm)に書き出す。実機なしで絵を確認できる。
//
//   使い方 (Icarus Verilog の場合):
//     iverilog -o sim vga_640x480.v draw_test.v top.v tb_vga_test.v
//     vvp sim
//     → frame.ppm が出来る (ImageMagick等でPNGに変換可)
// =============================================================
`timescale 1ns/1ps
module tb_vga_test;
    reg clk = 0;
    always #1 clk = ~clk;   // 適当なクロック

    wire        hsync, vsync;
    wire [1:0]  r, g, b;

    top dut (
        .clk_in (clk),
        .hsync  (hsync),
        .vsync  (vsync),
        .vga_r  (r),
        .vga_g  (g),
        .vga_b  (b)
    );

    // 内部信号を参照して表示領域だけ書き出す
    integer f;
    integer px, py;
    integer cap_x, cap_y;

    // 2bit(0..3) を 8bit(0..255) に伸ばす
    function [7:0] expand;
        input [1:0] v;
        begin
            expand = {v, v, v, v};  // 00→0, 01→85, 10→170, 11→255
        end
    endfunction

    initial begin
        // 1フレーム待ってからキャプチャしたいので、数フレーム回す
        // ここでは簡単に最初のフレームを撮る
        f = $fopen("frame.ppm", "w");
        $fwrite(f, "P3\n640 480\n255\n");

        // h_count / v_count を直接見て、(x,y)=(px,py) になった瞬間に記録
        for (py = 0; py < 480; py = py + 1) begin
            for (px = 0; px < 640; px = px + 1) begin
                // その座標になるまで待つ
                wait (dut.x == px && dut.y == py);
                $fwrite(f, "%0d %0d %0d\n",
                        expand(r), expand(g), expand(b));
                @(posedge clk);
            end
        end
        $fclose(f);
        $display("frame.ppm written");
        $finish;
    end
endmodule
