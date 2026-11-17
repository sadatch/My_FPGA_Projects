// serial_mul.sv -- 符号付き直列乗算器 (shift-add)
//   p = (a * b) >>> 16   (Q16.16 同士の積を Q16.16 に戻す。床関数の丸め)
//   32 サイクルで加算 + 1 サイクルで符号処理。DSP を使わないので 100 MHz でも
//   タイミングが厳しくならない。ニューロン更新は 0.25 ms (=25000clk) に 1 回なので十分速い。
//   start を 1 クロック与えると、約 34 クロック後に done が 1 クロック立つ。
module serial_mul (
    input  logic               clk,
    input  logic               rst,
    input  logic               start,
    input  logic signed [31:0] a,
    input  logic signed [31:0] b,
    output logic               done,
    output logic signed [31:0] p
);
    logic [63:0] mcand;
    logic [31:0] mplier;
    logic [63:0] acc;
    logic        neg;
    logic [5:0]  cnt;
    logic        busy;
    logic        fin;

    // 絶対値（|-2^31| は扱わない。Q16.16 で ±32768 以内の値しか来ない前提）
    wire [31:0] abs_a = a[31] ? (~a + 32'd1) : a;
    wire [31:0] abs_b = b[31] ? (~b + 32'd1) : b;

    wire [63:0] acc_next = acc + (mplier[0] ? mcand : 64'd0);
    wire [63:0] prod     = neg ? (~acc + 64'd1) : acc;   // 符号付き積（2の補数）

    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            busy <= 1'b0;
            fin  <= 1'b0;
        end else if (start && !busy && !fin) begin
            neg    <= a[31] ^ b[31];
            mcand  <= {32'd0, abs_a};
            mplier <= abs_b;
            acc    <= 64'd0;
            cnt    <= 6'd0;
            busy   <= 1'b1;
        end else if (busy) begin
            acc    <= acc_next;
            mcand  <= mcand << 1;
            mplier <= mplier >> 1;
            cnt    <= cnt + 6'd1;
            if (cnt == 6'd31) begin
                busy <= 1'b0;
                fin  <= 1'b1;
            end
        end else if (fin) begin
            p    <= prod[47:16];     // >>> 16 と同じ（下位16bitを捨てる = 床）
            done <= 1'b1;
            fin  <= 1'b0;
        end
    end
endmodule
