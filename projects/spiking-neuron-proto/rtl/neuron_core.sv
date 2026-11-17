// neuron_core.sv -- 単一ニューロン（Izhikevich / LIF）、Q16.16 固定小数点、前進 Euler
//
//   tick を 1 クロック与えるたびに 1 ステップ (dt = 0.25 ms) 進める。
//   完了すると valid が 1 クロック立ち、v_rec / spike / u_out が確定する。
//
//   Izhikevich (mode=0):  dt = 2^-2
//     vv = v*v ; t1 = 0.04*vv ; bv = b*v ; du = a*(bv - u)
//     dv = t1 + 5v + 140 - u + I
//     v1 = v + dv>>>2 ; u1 = u + du>>>2          （v, u はどちらも旧値から計算）
//     v1 >= 30 なら 発火: 記録値=30, v<=c, u<=u1+d
//   LIF (mode=1):  tau=16ms なので dt/tau = 2^-6
//     dv = Vrest - v + I ; v1 = v + dv>>>6
//     v1 >= -50 なら 発火: 記録値=30(表示用), v<=-65
//
//   python/ref_model.py の fixed_* とビット単位で一致させること。
module neuron_core (
    input  logic               clk,
    input  logic               rst,
    input  logic               tick,
    input  logic               mode,        // 0: Izhikevich, 1: LIF
    input  logic signed [31:0] I_in,        // 入力電流 Q16.16
    input  logic signed [31:0] pa,          // Izhikevich a,b,c,d (Q16.16)
    input  logic signed [31:0] pb,
    input  logic signed [31:0] pc,
    input  logic signed [31:0] pd,
    output logic signed [31:0] v_rec,       // 記録用の膜電位（発火ステップは 30 mV）
    output logic signed [31:0] u_out,
    output logic               spike,
    output logic               valid
);
    localparam logic signed [31:0] V_PEAK  =  32'sd1966080;   //  30 << 16
    localparam logic signed [31:0] V_INIT  = -32'sd4259840;   // -65 << 16
    localparam logic signed [31:0] C140    =  32'sd9175040;   // 140 << 16
    localparam logic signed [31:0] K004    =  32'sd2621;      // round(0.04 * 2^16)
    localparam logic signed [31:0] V_REST  = -32'sd4259840;   // -65 << 16
    localparam logic signed [31:0] V_RESET = -32'sd4259840;   // LIF リセット -65
    localparam logic signed [31:0] V_TH    = -32'sd3276800;   // LIF しきい値 -50 << 16

    typedef enum logic [3:0] {
        S_IDLE, S_MUL1, S_MUL2, S_MUL3, S_MUL4,
        S_SUM1, S_SUM2, S_LIF, S_NXT, S_UPD
    } state_t;
    state_t st;

    logic signed [31:0] v, u, ireg, t1, du, s1, dv, v1, u1;
    logic signed [31:0] mul_a, mul_b;
    logic               mul_start;
    logic               mul_done;
    logic signed [31:0] mul_p;

    serial_mul u_mul (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(mul_a), .b(mul_b), .done(mul_done), .p(mul_p)
    );

    assign u_out = u;

    always_ff @(posedge clk) begin
        mul_start <= 1'b0;
        valid     <= 1'b0;
        if (rst) begin
            st    <= S_IDLE;
            v     <= V_INIT;
            u     <= -((pb <<< 6) + pb);      // u0 = b * (-65) （厳密に b*v0 と一致）
            spike <= 1'b0;
            v_rec <= V_INIT;
        end else begin
            case (st)
                S_IDLE: if (tick) begin
                    ireg <= I_in;
                    if (mode) st <= S_LIF;
                    else begin
                        mul_a <= v; mul_b <= v; mul_start <= 1'b1;   // vv = v*v
                        st <= S_MUL1;
                    end
                end
                S_MUL1: if (mul_done) begin                          // t1 = 0.04 * vv
                    mul_a <= mul_p; mul_b <= K004; mul_start <= 1'b1;
                    st <= S_MUL2;
                end
                S_MUL2: if (mul_done) begin                          // bv = b * v
                    t1 <= mul_p;
                    mul_a <= pb; mul_b <= v; mul_start <= 1'b1;
                    st <= S_MUL3;
                end
                S_MUL3: if (mul_done) begin                          // du = a * (bv - u)
                    mul_a <= pa; mul_b <= mul_p - u; mul_start <= 1'b1;
                    st <= S_MUL4;
                end
                S_MUL4: if (mul_done) begin
                    du <= mul_p;
                    st <= S_SUM1;
                end
                S_SUM1: begin s1 <= t1 + v + (v <<< 2);        st <= S_SUM2; end   // t1 + 5v
                S_SUM2: begin dv <= s1 + C140 - u + ireg;      st <= S_NXT;  end
                S_LIF:  begin dv <= V_REST - v + ireg;         st <= S_NXT;  end
                S_NXT: begin
                    if (mode) begin
                        v1 <= v + (dv >>> 6);
                        u1 <= u;
                    end else begin
                        v1 <= v + (dv >>> 2);
                        u1 <= u + (du >>> 2);
                    end
                    st <= S_UPD;
                end
                S_UPD: begin
                    valid <= 1'b1;
                    if (mode ? (v1 >= V_TH) : (v1 >= V_PEAK)) begin
                        spike <= 1'b1;
                        v_rec <= V_PEAK;
                        v     <= mode ? V_RESET : pc;
                        u     <= mode ? u1 : (u1 + pd);
                    end else begin
                        spike <= 1'b0;
                        v_rec <= v1;
                        v     <= v1;
                        u     <= u1;
                    end
                    st <= S_IDLE;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
