module debounce (
    input  clk,
    input  btn_raw,
    output reg btn_clean = 0
);
    reg [15:0] cnt = 0;
    reg        btn_sync = 0;
    always @(posedge clk) begin
        btn_sync <= btn_raw;
        if (btn_sync == btn_clean) cnt <= 0;
        else begin
            cnt <= cnt + 1'b1;
            if (cnt == 16'hFFFF) btn_clean <= btn_sync;
        end
    end
endmodule