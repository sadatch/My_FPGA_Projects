module draw_main(
    input wire       clk,
    input wire       visible,
    input wire [9:0] x,
    input wire [9:0] y,
    input wire       frame_tick,
    output reg [1:0] r,
    output reg [1.0] g,
    output reg [1.0] b
);

    localparam box_width = 20;

    localparam BALL = 16;              // ボール一辺
    localparam PW   = 8,  PH = 64;     // パドル幅・高さ
    localparam BSPD = 2,  PSPD = 4;    // ボール速度・パドル速度
    localparam PADX_L = 16, PADX_R = 640 - 16 - PW;  // パドルのX位置(固定)

    // 点(px,py) が 左上(rx,ry)・幅w・高さh の矩形の中なら 1
    function in_rect;
        input [9:0] px, py;
        input [9:0] rx, ry;
        input [9:0] w,  h;
        begin
            in_rect = (px >= rx) && (px < rx + w) &&
                      (py >= ry) && (py < ry + h);
        end
    endfunction
    wire ball_on = in_rect(x, y, 312, 232, BALL, BALL);  // 中央に固定
    if (ball_on) {r,g,b} = {2'b11,2'b11,2'b11};          // 白い四角
    else         {r,g,b} = 6'b000000;

    wire padL_on = in_rect(x, y, PADX_L, 200, PW, PH);
    wire padR_on = in_rect(x, y, PADX_R, 200, PW, PH);

    always @(*) begin
        if (!visible)      {r,g,b} = 6'b000000;            // 表示領域外は黒
        else if (ball_on)  {r,g,b} = {2'b11,2'b11,2'b11};  // ボール=白
        else if (padL_on)  {r,g,b} = {2'b00,2'b10,2'b11};  // 左=青
        else if (padR_on)  {r,g,b} = {2'b00,2'b11,2'b01};  // 右=緑
        else               {r,g,b} = 6'b000000;            // それ以外=黒
    end

    wire border = (x<2) || (x>=638) || (y<2) || (y>=478);
    wire midline = (x>=319) && (x<321) && (y[4]==1'b0);

    always @(*) begin
        if (!visible)     {r,g,b} = 6'b000000;          //表示領域外は黒
        else if (border)  {r,g,b} = {2'b11,2'b11,2'b11}; //
        else if (midline) {r,g,b} = {2'b10,2'b10,2'b10}; //点線は白色
        else              {r,g,b} = 6'b000000;
    end

    wire frame_tick = (x==10'd0) && (y==10'd0);  // 左上を描く瞬間だけ1
    reg [9:0] ball_x = 312, ball_y = 232;
    reg       dirx = 1'b1, diry = 1'b1;   // 1:+方向, 0:-方向

    always @(posedge pix_clk) begin
        if (frame_tick) begin
            if (ball_y <= 2)            diry <= 1'b1;   // 上の壁 → 下向きへ
            if (ball_y + BALL >= 478)   diry <= 1'b0;   // 下の壁 → 上向きへ
            if (ball_x <= 2)            dirx <= 1'b1;    // 左の壁（あとで得点に変更）
            if (ball_x + BALL >= 638)   dirx <= 1'b0;    // 右の壁（あとで得点に変更）

            // ② 移動（Step5から既にある処理）
            ball_x <= dirx ? ball_x + BSPD : ball_x - BSPD;
            ball_y <= diry ? ball_y + BSPD : ball_y - BSPD;
        end
    end

    reg [9:0] padL_y = 200;
    reg [9:0] padR_y = 200;

    always @(posedge pix_clk) begin
        if (frame_tick) begin
            if (up_L   && padL_y > 2)        padL_y <= padL_y - PSPD;
            if (down_L && padL_y + PH < 478) padL_y <= padL_y + PSPD;

            if (up_R   && padR_y > 2)        padR_y <= padR_y - PSPD;
            if (down_R && padR_y + PH < 478) padR_y <= padR_y + PSPD;
        end
    end

    reg [19:0] refresh_cnt = 0;
    always @(posedge pix_clk) refresh_cnt <= refresh_cnt + 1'b1;

    wire [1:0] digit_sel = refresh_cnt[19:18];  

    reg [3:0] current_digit;
    reg [3:0] an;

    always @(*) begin
        case (digit_sel)
            2'b00: begin current_digit = scoreR; an = 4'b1110; end //一番右 右の人のスコア
            2'b01: begin current_digit = 4'hF;   an = 4'b1101; end //消灯
            2'b10: begin current_digit = scoreL; an = 4'b1011; end //一番左 左の人のスコア
            2'b11: begin current_digit = 4'hF;   an = 4'b0111; end //消灯
        endcase
    end

    always @(*) begin
        case (current_digit)
            //                   gfedcba
            4'h0: seg = 7'b1000000;  // 0
            4'h1: seg = 7'b1111001;  // 1
            4'h2: seg = 7'b0100100;  // 2
            4'h3: seg = 7'b0110000;  // 3
            4'h4: seg = 7'b0011001;  // 4
            4'h5: seg = 7'b0010010;  // 5
            4'h6: seg = 7'b0000010;  // 6
            4'h7: seg = 7'b1111000;  // 7
            4'h8: seg = 7'b0000000;  // 8
            4'h9: seg = 7'b0010000;  // 9
            default: seg = 7'b1111111; // 消灯
        endcase
    end
    


    


endmodule