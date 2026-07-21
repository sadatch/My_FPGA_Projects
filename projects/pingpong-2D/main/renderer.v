module renderer(
    input wire [9:0] x,
    input wire [9:0] y,
    input wire visible,
    output reg [3:0] vgaRed,
    output reg [3:0] vgaGreen,
    output reg [3:0] vgaBlue
);
    localparam BALL = 16;
    localparam PW = 8, PH = 64; //パドル幅・高さ
    localparam PADX_L = 16, PADX_R = 640 - 16 - PW; //パドルのX位置(固定)

    // 点(px,py) が 左上(rx,ry)・幅w・高さh の矩形の中なら 1
    function in_rect;
        input [9:0] px, py;
        input [9:0] rx, ry;
        input [9:0] w, h;
        begin
            in_rect = (px >= rx) && (px < rx + w) &&
                      (py >= ry) && (py < ry + h);
        end
    endfunction

    // ----各パーツの短形判定 ----
    wire ball_on = in_rect(x, y, 312, 232, BALL, BALL);
    wire padL_on = in_rect(x, y, PADX_L, 200, PW, PH);
    wire padR_on = in_rect(x, y, PADX_R, 200, PW, PH);
    wire border  = (x < 2) || (x >= 638) || (y < 2) || (y >= 478);
    wire midline = (x >= 319) && (x < 321) && (y[4] == 1'b0);

    // ----　色を決める ----
    always @(*) begin
        if (!visible) begin
            vgaRed = 4'h0; vgaGreen = 4'h0; vgaBlue = 4'h0; // 表示領域外 = 黒
        end else if (ball_on) begin
            vgaRed = 4'hF; vgaGreen = 4'hF; vgaBlue = 4'hF; //ボールは白色
        end else if (padL_on) begin
            vgaRed = 4'h0; vgaGreen = 4'h4; vgaBlue = 4'hF; //左パドルは青
        end else if (padR_on) begin
            vgaRed = 4'hF; vgaGreen = 4'h0; vgaBlue = 4'h0; //右パドルは赤
        end else if (border) begin
            vgaRed = 4'hF; vgaGreen = 4'hF; vgaBlue = 4'hF;   // 枠=白
        end else if (midline) begin
            vgaRed = 4'h8; vgaGreen = 4'h8; vgaBlue = 4'h8;   // 中央点線=灰
        end else begin
            vgaRed = 4'h0; vgaGreen = 4'h0; vgaBlue = 4'h0;  //背景は黒
        end
    end
endmodule