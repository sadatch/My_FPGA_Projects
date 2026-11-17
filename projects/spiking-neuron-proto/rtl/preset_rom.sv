// preset_rom.sv -- Izhikevich のパラメータ (a,b,c,d) を Q16.16 で返す
//   sel: 0=RS  1=IB  2=CH  3=FS      (Izhikevich 2003, Fig.2)
//   値は python/ref_model.py の PRESETS と一致していること（run_tests.py が確認する）
module preset_rom (
    input  logic [1:0]         sel,
    output logic signed [31:0] a,
    output logic signed [31:0] b,
    output logic signed [31:0] c,
    output logic signed [31:0] d
);
    always_comb begin
        b = 32'sd13107;                                  // 0.2
        case (sel)
            2'd0: begin a = 32'sd1311; c = -32'sd4259840; d = 32'sd524288; end  // RS: .02,.2,-65,8
            2'd1: begin a = 32'sd1311; c = -32'sd3604480; d = 32'sd262144; end  // IB: .02,.2,-55,4
            2'd2: begin a = 32'sd1311; c = -32'sd3276800; d = 32'sd131072; end  // CH: .02,.2,-50,2
            default: begin a = 32'sd6554; c = -32'sd4259840; d = 32'sd131072; end // FS: .1,.2,-65,2
        endcase
    end
endmodule
