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

    assign led = 16'h0000;
    assign seg = 7'b1111111;
    assign dp = 1;
    assign an = 4'b1111;

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

    wire [9:0] ball_x, ball_y;
    wire [9:0] pad_L_y, pad_R_y;
    wire [3:0] scoreL, scoreR;
    reg frame_tick;
    always @(*) begin
        if ((x == 0) && (y == 0)) begin
            frame_tick = 1;
        end else begin
            frame_tick = 0;
        end
    end

    game_logic u_game_logic (
        .clk(pix_clk),
        .rst(btnC),
        .frame_tick(frame_tick),
        .up_L(btnU),
        .down_L(btnL),
        .up_R(btnR),
        .down_R(btnD),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .pad_L_y(pad_L_y),
        .pad_R_y(pad_R_y),
        .scoreL(scoreL),
        .scoreR(scoreR)

    );

    

    renderer u_renderer (
        .x(x),
        .y(y),
        .visible(visible),
        .ball_x(ball_x),
        .ball_y(ball_y),
        .pad_L_y(pad_L_y),
        .pad_R_y(pad_R_y),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue)
    );

endmodule
