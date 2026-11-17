// uart_tx.sv -- UART 送信 (8N1)
//   CLKS_PER_BIT = clk周波数 / ボーレート.  100MHz / 921600 = 108.5 -> 109 (誤差 0.46%)
//   start を 1 クロック与えると data を送信。busy の間は start を無視。
module uart_tx #(
    parameter int CLKS_PER_BIT = 109
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] data,
    output logic       tx,
    output logic       busy
);
    typedef enum logic [1:0] { S_IDLE, S_START, S_DATA, S_STOP } state_t;
    state_t      st;
    logic [15:0] cnt;
    logic [2:0]  bitn;
    logic [7:0]  sh;

    assign busy = (st != S_IDLE);

    always_ff @(posedge clk) begin
        if (rst) begin
            st <= S_IDLE;
            tx <= 1'b1;
        end else begin
            case (st)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (start) begin
                        sh  <= data;
                        cnt <= 16'd0;
                        tx  <= 1'b0;              // スタートビット
                        st  <= S_START;
                    end
                end
                S_START: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt  <= 16'd0;
                        tx   <= sh[0];            // bit0 (LSB first)
                        sh   <= {1'b0, sh[7:1]};
                        bitn <= 3'd0;
                        st   <= S_DATA;
                    end else cnt <= cnt + 16'd1;
                end
                S_DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt <= 16'd0;
                        if (bitn == 3'd7) begin
                            tx <= 1'b1;           // ストップビット
                            st <= S_STOP;
                        end else begin
                            tx   <= sh[0];
                            sh   <= {1'b0, sh[7:1]};
                            bitn <= bitn + 3'd1;
                        end
                    end else cnt <= cnt + 16'd1;
                end
                S_STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) st <= S_IDLE;
                    else cnt <= cnt + 16'd1;
                end
            endcase
        end
    end
endmodule
