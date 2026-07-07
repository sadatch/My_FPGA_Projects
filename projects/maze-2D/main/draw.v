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

    reg [9:0] box_x = 320;
    reg [9:0] box_y = 240;

endmodule