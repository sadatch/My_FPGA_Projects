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

    wire clean_btnU;
    wire clean_btnD;
    wire clean_btnL;
    wire clean_btnR;
    wire clean_btnC;

    debounce btnU_debounce (
        .clk(pix_clk),
        .btn_raw(btnU),
        .btn_clean(clean_btnU)
    );

    debounce btnD_debounce (
        .clk(pix_clk),
        .btn_raw(btnD),
        .btn_clean(clean_btnD)
    );

    debounce btnL_debounce (
        .clk(pix_clk),
        .btn_raw(btnL),
        .btn_clean(clean_btnL)
    );

    debounce btnR_debounce (
        .clk(pix_clk),
        .btn_raw(btnR),
        .btn_clean(clean_btnR)
    );

    debounce btnC_debounce (
        .clk(pix_clk),
        .btn_raw(btnC),
        .btn_clean(clean_btnC)
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
        .rst(clean_btnC),
        .frame_tick(frame_tick),
        .up_L(clean_btnU),
        .down_L(clean_btnL),
        .up_R(clean_btnR),
        .down_R(clean_btnD),
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
