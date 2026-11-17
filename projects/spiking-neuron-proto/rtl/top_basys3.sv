// top_basys3.sv -- Basys3 トップ: 単一ニューロン + VGA 波形 + UART + 7セグ + LED
//
//   スイッチ  sw[7:0]   入力電流 I = sw * 0.25   (40 -> I=10)
//             sw[9:8]   Izhikevich プリセット 0=RS 1=IB 2=CH 3=FS
//             sw[11:10] VGA 時間軸 0:x1(160ms) 1:x2(320ms) 2:x4(640ms) 3:x8(1.28s)
//             sw[15]    0: Izhikevich / 1: LIF   (LIF は I>60 付近で発火)
//   btnC      リセット
//   LED       led[0]=発火 (約40msに引き伸ばし)  led[1]=mode  led[3:2]=preset
//   7セグ     直近 1 秒間の発火数 [Hz]
//   UART      921600 baud 8N1, 4byte/サンプル (rtl/uart_frame_tx.sv 参照)
//   VGA       640x480@60Hz, 25MHz相当は 100MHz の 1/4 イネーブルで生成
module top_basys3 #(
    parameter int TICK_DIV = 25000,     // 100MHz/25000 = 4kHz -> dt=0.25ms (実時間)
    parameter int CPB      = 109,       // 100MHz/921600
    parameter int RATE_WIN = 4000       // 発火率を数える窓 [ステップ] = 1秒
) (
    input  logic        clk,
    input  logic [15:0] sw,
    input  logic        btnC,
    output logic [15:0] led,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an,
    output logic        Hsync,
    output logic        Vsync,
    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue,
    output logic        RsTx
);
    // ---------------- リセットと入力の同期 ----------------
    logic [7:0]  por   = 8'd0;
    logic [1:0]  btn_s = 2'b00;
    logic [15:0] sw_m  = 16'd0;
    logic [15:0] sw_s  = 16'd0;
    always_ff @(posedge clk) begin
        if (por != 8'hFF) por <= por + 8'd1;
        btn_s <= {btn_s[0], btnC};
        sw_m  <= sw;
        sw_s  <= sw_m;
    end
    wire rst = btn_s[1] | (por != 8'hFF);

    wire [7:0] i_sw    = sw_s[7:0];
    wire [1:0] preset  = sw_s[9:8];
    wire [1:0] dec_sel = sw_s[11:10];
    wire       mode    = sw_s[15];
    wire signed [31:0] I_in = {10'd0, i_sw, 14'd0};          // sw * 0.25 in Q16.16

    // ---------------- ニューロン ----------------
    wire tick;
    tick_gen #(.DIV(TICK_DIV)) u_tick (.clk(clk), .rst(rst), .tick(tick));

    wire signed [31:0] pa, pb, pc, pd;
    preset_rom u_rom (.sel(preset), .a(pa), .b(pb), .c(pc), .d(pd));

    wire signed [31:0] v_rec, u_out;
    wire core_spike, core_valid;
    neuron_core u_core (
        .clk(clk), .rst(rst), .tick(tick), .mode(mode), .I_in(I_in),
        .pa(pa), .pb(pb), .pc(pc), .pd(pd),
        .v_rec(v_rec), .u_out(u_out), .spike(core_spike), .valid(core_valid)
    );

    // ---------------- UART ----------------
    uart_frame_tx #(.CLKS_PER_BIT(CPB)) u_frame (
        .clk(clk), .rst(rst), .push(core_valid),
        .v16(v_rec[23:8]), .flags({preset, mode, core_spike}), .tx(RsTx)
    );

    // ---------------- VGA ----------------
    logic [1:0] pcnt = 2'd0;
    always_ff @(posedge clk) pcnt <= pcnt + 2'd1;
    wire ce = (pcnt == 2'd3);

    wire [9:0] vx, vy;
    wire vvis, vhs, vvs;
    vga_timing u_vga (.clk(clk), .ce(ce), .x(vx), .y(vy), .visible(vvis), .hsync(vhs), .vsync(vvs));

    wire [3:0] wr, wg, wb;
    wave_display u_wave (
        .clk(clk), .ce(ce), .x(vx), .y(vy), .visible(vvis),
        .sample_valid(core_valid), .v_rec(v_rec), .spike(core_spike), .dec_sel(dec_sel),
        .r(wr), .g(wg), .b(wb)
    );

    // 色と同じタイミングで同期信号も出す（どちらも ce で 1 段レジスタ）
    logic hs_r = 1'b1, vs_r = 1'b1;
    always_ff @(posedge clk) if (ce) begin hs_r <= vhs; vs_r <= vvs; end
    assign Hsync    = hs_r;
    assign Vsync    = vs_r;
    assign vgaRed   = wr;
    assign vgaGreen = wg;
    assign vgaBlue  = wb;

    // ---------------- 発火率 -> 7セグ ----------------
    logic [12:0] win_cnt;
    logic [13:0] spk_cnt, rate;
    logic        bcd_start;
    always_ff @(posedge clk) begin
        bcd_start <= 1'b0;
        if (rst) begin
            win_cnt <= 13'd0; spk_cnt <= 14'd0; rate <= 14'd0;
        end else if (core_valid) begin
            if (win_cnt == RATE_WIN - 1) begin
                win_cnt   <= 13'd0;
                rate      <= spk_cnt + {13'd0, core_spike};
                spk_cnt   <= 14'd0;
                bcd_start <= 1'b1;
            end else begin
                win_cnt <= win_cnt + 13'd1;
                spk_cnt <= spk_cnt + {13'd0, core_spike};
            end
        end
    end

    logic [15:0] bcd_val = 16'd0;
    wire  [15:0] bcd_new;
    wire         bcd_done;
    bin2bcd u_bcd (.clk(clk), .rst(rst), .start(bcd_start), .bin(rate), .bcd(bcd_new), .done(bcd_done));
    always_ff @(posedge clk) if (bcd_done) bcd_val <= bcd_new;

    seg7_4digit u_seg (.clk(clk), .bcd(bcd_val), .seg(seg), .an(an));
    assign dp = 1'b1;

    // ---------------- LED ----------------
    logic [21:0] stretch = 22'd0;
    always_ff @(posedge clk) begin
        if (core_valid && core_spike) stretch <= 22'h3FFFFF;       // ~42 ms
        else if (stretch != 22'd0)    stretch <= stretch - 22'd1;
    end
    assign led = {12'd0, preset, mode, (stretch != 22'd0)};
endmodule
