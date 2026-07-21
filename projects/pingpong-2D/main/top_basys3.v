module top_basys3(
    input  wire clk,          // 100MHz
    input wire btnC,         // 中央ボタン
    input  wire btnU,         // 上ボタン
    input  wire btnD,         // 下ボタン
    input  wire btnL,         // 左ボタン
    input  wire btnR,         // 右ボタン
    output wire Hsync,        // VGA水平同期信号
    output wire Vsync,        // VGA垂直同期信号
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire [15:0] led,
    output wire [6:0] seg,
    output wire       dp,
    output wire [3:0] an
);
    wire pix_clk;
    clk_div25 u_clkdiv (
        .clk_in(clk),
        .clk_out(pix_clk)
    );

    wire [9:0] x, y;
    wire visible;
    vga_640x480 u_vga (
        .pix_clk(pix_clk),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .visible(visible),
        .x(x),
        .y(y)
    );

    renderer u_renderer (
        .x(x),
        .y(y),
        .visible(visible),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue)
    );

endmodule
