module game_logic(
    input wire clk,
    input wire  rst,
    input wire  frame_tick,
    input wire up_L,
    input wire down_L,
    input wire up_R,
    input wire down_R,

    input wire hitL,
    input wire hitR,
    output reg [9:0] ball_x = 312,
    output reg [9:0] ball_y = 232,
    output reg [9:0] pad_L_y = 200,
    output reg [9:0] pad_R_y = 200,
    output reg [3:0] scoreL = 0,
    output reg [3:0] scoreR = 0
);
    localparam BALL = 16;
    localparam PW = 8;
    localparam PH = 64;
    localparam BSPD = 2;
    localparam PSPD = 8;
    localparam PADX_L = 16;
    localparam PADX_R = 640 - 16 - PW;

    reg dirx = 1;
    reg diry = 1;

    always @(posedge clk) begin
        if (frame_tick) begin
            if (ball_y <= 2) begin
                diry <= 1;
            end
            if (ball_y + BALL >= 478) begin
                diry <= 0;
            end
            if (ball_x <= 2) begin
                dirx <= 1;
            end
            if (ball_x + BALL >= 638) begin
                dirx <= 0;
            end
            
            if (diry) begin
                ball_y <= ball_y + BSPD;
            end
            else begin
                ball_y <= ball_y - BSPD;
            end

            if (dirx) begin
                ball_x <= ball_x + BSPD;
            end
            else begin
                ball_x <= ball_x - BSPD;
            end


        end



        
    end

    always @(posedge clk) begin
        if (frame_tick) begin
            if (up_L && pad_L_y > 2) begin
                pad_L_y <= pad_L_y - PSPD;
            end
            if (down_L && pad_L_y + PH < 478) begin
                pad_L_y <= pad_L_y + PSPD;
            end
            if (up_R && pad_R_y > 2) begin
                pad_R_y <= pad_R_y - PSPD;
            end
            if (down_R && pad_R_y + PH < 478) begin
                pad_R_y <= pad_R_y + PSPD;
            end
        end
    end
            


endmodule