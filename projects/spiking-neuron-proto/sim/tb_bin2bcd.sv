// tb_bin2bcd.sv -- bin2bcd の自己検査テスト
`timescale 1ns/1ps
module tb_bin2bcd;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst = 1'b1, start = 1'b0;
    logic [13:0] bin = 14'd0;
    logic [15:0] bcd;
    logic done;
    bin2bcd dut (.clk(clk), .rst(rst), .start(start), .bin(bin), .bcd(bcd), .done(done));

    integer fails = 0, n = 0;
    integer vals [0:9];
    integer i, exp_bcd;

    function automatic [15:0] to_bcd(input integer x);
        reg [3:0] d3, d2, d1, d0;
        begin
            d3 = (x / 1000) % 10;
            d2 = (x / 100) % 10;
            d1 = (x / 10) % 10;
            d0 = x % 10;
            to_bcd = {d3, d2, d1, d0};
        end
    endfunction

    initial begin
        vals[0] = 0;   vals[1] = 7;    vals[2] = 10;  vals[3] = 99;   vals[4] = 100;
        vals[5] = 1234; vals[6] = 4000; vals[7] = 5678; vals[8] = 9999; vals[9] = 305;
        repeat (3) @(posedge clk);
        #1 rst = 1'b0;
        for (i = 0; i < 10; i = i + 1) begin
            #1 bin = vals[i]; start = 1'b1;
            @(posedge clk); #1 start = 1'b0;
            while (!done) begin @(posedge clk); #1; end
            exp_bcd = to_bcd(vals[i]);
            n = n + 1;
            if (bcd !== exp_bcd[15:0]) begin
                fails = fails + 1;
                $display("FAIL bin=%0d bcd=%h expected=%h", vals[i], bcd, exp_bcd[15:0]);
            end
        end
        if (fails == 0) $display("PASS bin2bcd: %0d values", n);
        else            $display("FAIL bin2bcd: %0d / %0d", fails, n);
        $finish;
    end
endmodule
