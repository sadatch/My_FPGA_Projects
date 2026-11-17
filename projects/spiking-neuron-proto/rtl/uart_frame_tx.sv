// uart_frame_tx.sv -- 1サンプル = 4バイトのフレームを送る
//   byte0: 0xA5 (同期)
//   byte1: v[7:0]     v は Q8.8 の int16 (= v_rec[23:8]), リトルエンディアン
//   byte2: v[15:8]
//   byte3: {seq[3:0], preset[1:0], mode, spike}
//   push を 1 クロック与えるとフレーム送信を開始（送信中の push は捨てる）。
module uart_frame_tx #(
    parameter int CLKS_PER_BIT = 109
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        push,
    input  logic [15:0] v16,
    input  logic [3:0]  flags,      // {preset[1:0], mode, spike}
    output logic        tx
);
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_uart (
        .clk(clk), .rst(rst), .start(tx_start), .data(tx_data), .tx(tx), .busy(tx_busy)
    );

    logic [7:0] b1, b2, b3;
    logic [3:0] seq;
    logic [2:0] idx;
    logic       sending;

    always_ff @(posedge clk) begin
        tx_start <= 1'b0;
        if (rst) begin
            sending <= 1'b0;
            seq     <= 4'd0;
            idx     <= 3'd0;
        end else if (!sending) begin
            if (push) begin
                b1  <= v16[7:0];
                b2  <= v16[15:8];
                b3  <= {seq, flags};
                seq <= seq + 4'd1;
                idx <= 3'd0;
                sending <= 1'b1;
            end
        end else if (!tx_busy && !tx_start) begin
            if (idx == 3'd4) sending <= 1'b0;
            else begin
                tx_start <= 1'b1;
                case (idx)
                    3'd0:    tx_data <= 8'hA5;
                    3'd1:    tx_data <= b1;
                    3'd2:    tx_data <= b2;
                    default: tx_data <= b3;
                endcase
                idx <= idx + 3'd1;
            end
        end
    end
endmodule
