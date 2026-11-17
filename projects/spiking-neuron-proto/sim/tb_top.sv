// tb_top.sv -- 最上位まで通した確認
//   ・UART の TX ピンを復号して全フレームをファイルに書く（Python 側で参照モデルと照合）
//   ・VGA の 1 フレームを PPM に書く（Python 側で PNG に変換して目視）
//   ・7セグ用の発火率(BCD) を表示
//   実機と同じ構造だが、TICK_DIV を縮めて速く回す（UART が間に合う 5000 を使う）。
//   iverilog -Ptb_top.TICK_DIV=5000 ...
`timescale 1ns/1ps
module tb_top;
    parameter int TICK_DIV = 5000;
    parameter int CPB      = 109;
    parameter int RATE_WIN = 400;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic [15:0] sw = 16'h0400;      // I=0, RS, 時間軸 x2, Izhikevich
    logic btnC = 1'b0;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;
    wire        Hsync, Vsync, RsTx;
    wire [3:0]  vgaRed, vgaGreen, vgaBlue;

    top_basys3 #(.TICK_DIV(TICK_DIV), .CPB(CPB), .RATE_WIN(RATE_WIN)) dut (
        .clk(clk), .sw(sw), .btnC(btnC), .led(led), .seg(seg), .dp(dp), .an(an),
        .Hsync(Hsync), .Vsync(Vsync), .vgaRed(vgaRed), .vgaGreen(vgaGreen), .vgaBlue(vgaBlue),
        .RsTx(RsTx)
    );

    integer steps = 1200;
    reg [8*256-1:0] uart_name, ppm_name;
    integer fu, fp, i;

    // ---- tick を数える ----
    integer nticks = 0;
    always @(posedge clk) if (dut.tick) nticks <= nticks + 1;

    // ---- 刺激: 80 ステップは I=0、その後 I=10 (sw=40) ----
    initial begin
        void'($value$plusargs("steps=%d", steps));
        wait (nticks == 80);
        repeat (TICK_DIV / 2) @(posedge clk);
        sw[7:0] = 8'd40;
    end

    // ---- UART 復号 ----
    initial begin : uart_rx
        logic [7:0] b;
        integer j;
        uart_name = "uart_hex.txt";
        void'($value$plusargs("uart=%s", uart_name));
        fu = $fopen(uart_name, "w");
        forever begin
            @(negedge RsTx);
            repeat (CPB / 2) @(posedge clk);
            for (j = 0; j < 8; j = j + 1) begin
                repeat (CPB) @(posedge clk);
                b[j] = RsTx;
            end
            repeat (CPB - 10) @(posedge clk);
            $fdisplay(fu, "%02x", b);
        end
    end

    // ---- VGA ピクセル取り込み ----
    logic [11:0] frame [0:307199];
    logic [9:0] px = 10'd0, py = 10'd0;
    logic pvis = 1'b0;
    always @(posedge clk) if (dut.ce) begin
        if (pvis) frame[py * 640 + px] <= {vgaRed, vgaGreen, vgaBlue};
        px   <= dut.vx;
        py   <= dut.vy;
        pvis <= dut.vvis;
    end

    // ---- 終了処理 ----
    initial begin
        ppm_name = "frame.ppm";
        void'($value$plusargs("ppm=%s", ppm_name));
        for (i = 0; i < 307200; i = i + 1) frame[i] = 12'd0;
        wait (nticks >= steps);
        repeat (TICK_DIV) @(posedge clk);              // 最後の UART フレームを送り切る
        @(posedge clk);
        while (!(dut.ce && dut.vx == 10'd0 && dut.vy == 10'd500)) @(posedge clk);
        fp = $fopen(ppm_name, "w");
        $fdisplay(fp, "P3");
        $fdisplay(fp, "640 480");
        $fdisplay(fp, "255");
        for (i = 0; i < 307200; i = i + 1)
            $fdisplay(fp, "%0d %0d %0d", frame[i][11:8] * 17, frame[i][7:4] * 17, frame[i][3:0] * 17);
        $fclose(fp);
        $fclose(fu);
        $display("ticks=%0d  BCD=%h  led=%b", nticks, dut.bcd_val, led);
        $finish;
    end

    initial begin
        #4000000000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
