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

endmodule