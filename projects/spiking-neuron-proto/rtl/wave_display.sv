// wave_display.sv -- 膜電位をオシロスコープ風に VGA へ描く
//
//   ・サンプル(v_rec)を間引いて、1024 エントリのリングバッファに積む
//   ・表示は「最新 640 サンプル」。フレーム先頭で書き込み位置を保存して固定するので
//     走査中にバッファが進んでも画面が崩れない（書き込み先は表示範囲の外にある:
//     1024-640=384 サンプル分の余裕。dec=1 でも 1 フレーム ~67 サンプルなので十分）
//   ・各列は「1つ前の列の y」と「この列の y」の間を縦に塗る -> 急な発火でも線が切れない
//   ・座標変換: y_pix = 140 - 4*floor(v[mV])   (+30mV -> 20,  -65mV -> 400)
//   ・発火を含む列は赤、それ以外は緑。0mV と -65mV に薄いガイド線。
module wave_display (
    input  logic               clk,
    input  logic               ce,            // ピクセルイネーブル
    input  logic [9:0]         x,
    input  logic [9:0]         y,
    input  logic               visible,
    input  logic               sample_valid,  // 1ステップ更新ごとの 1 クロックパルス
    input  logic signed [31:0] v_rec,         // Q16.16
    input  logic               spike,
    input  logic [1:0]         dec_sel,       // 0:x1 1:x2 2:x4 3:x8
    output logic [3:0]         r,
    output logic [3:0]         g,
    output logic [3:0]         b
);
    // ---- v -> y 座標 ----
    wire signed [9:0]  vi    = v_rec[25:16];                       // 整数 mV (床)
    wire signed [12:0] y_raw = 13'sd140 - ({{3{vi[9]}}, vi} <<< 2);
    wire [8:0] y_clamped = (y_raw < 0) ? 9'd0 : (y_raw > 13'sd479) ? 9'd479 : y_raw[8:0];

    // ---- 間引き + 書き込み ----
    logic [9:0] mem [0:1023];                // {spike, y[8:0]}
    logic [9:0] wp      = 10'd0;
    logic [2:0] dcnt    = 3'd0;
    logic       spk_acc = 1'b0;

    wire [2:0] dmax      = (3'd1 << dec_sel) - 3'd1;
    wire       spk_n     = spk_acc | spike;
    wire [8:0] y_store   = spk_n ? 9'd20 : y_clamped;     // 窓内に発火があればピークを描く

    // メモリは always @(posedge) で書く（initial での初期化と同居させるため。LUTRAM の初期値になる）
    integer i;
    initial for (i = 0; i < 1024; i = i + 1) mem[i] = 10'd400;   // 静止電位(-65mV)の高さ

    always @(posedge clk)
        if (sample_valid && dcnt >= dmax) mem[wp] <= {spk_n, y_store};

    always_ff @(posedge clk) begin
        if (sample_valid) begin
            if (dcnt >= dmax) begin
                wp      <= wp + 10'd1;
                dcnt    <= 3'd0;
                spk_acc <= 1'b0;
            end else begin
                dcnt    <= dcnt + 3'd1;
                spk_acc <= spk_n;
            end
        end
    end

    // ---- 表示側 ----
    logic [9:0] wp_lat = 10'd0;
    always_ff @(posedge clk)
        if (ce && x == 10'd0 && y == 10'd490) wp_lat <= wp;   // ブランキング中に固定

    wire [9:0] a_cur = wp_lat + 10'd384 + x;                  // = wp_lat - 640 + x  (mod 1024)
    wire [9:0] a_prv = (x == 10'd0) ? a_cur : (a_cur - 10'd1);
    wire [9:0] s_cur = mem[a_cur];
    wire [9:0] s_prv = mem[a_prv];
    wire [8:0] yc = s_cur[8:0];
    wire [8:0] yp = s_prv[8:0];
    wire [8:0] lo = (yc < yp) ? yc : yp;
    wire [8:0] hi = (yc < yp) ? yp : yc;

    wire on_wave = (y[8:0] >= lo) && (y[8:0] <= hi);
    wire spk_col = s_cur[9] | s_prv[9];                       // 発火の立ち上がり列と降下列をどちらも赤にする
    wire grid    = (y == 10'd140) || (y == 10'd400) || (x[5:0] == 6'd0 && y[2] == 1'b0);

    always_ff @(posedge clk) begin
        if (ce) begin
            if (!visible) begin
                r <= 4'h0; g <= 4'h0; b <= 4'h0;
            end else if (on_wave) begin
                if (spk_col) begin r <= 4'hF; g <= 4'h3; b <= 4'h3; end    // 発火: 赤
                else          begin r <= 4'h3; g <= 4'hF; b <= 4'h5; end   // 通常: 緑
            end else if (grid) begin
                r <= 4'h3; g <= 4'h3; b <= 4'h3;
            end else begin
                r <= 4'h0; g <= 4'h0; b <= 4'h0;
            end
        end
    end
endmodule
