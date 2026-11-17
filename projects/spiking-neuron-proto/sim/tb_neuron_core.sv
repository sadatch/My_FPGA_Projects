// tb_neuron_core.sv -- neuron_core を Python 参照モデルと比較するためのテストベンチ
//   plusargs:  +mode=0/1  +preset=0..3  +Iq=<Q16.16 整数>  +steps=<N>  +on=<立ち上げステップ>  +out=<csv>
//   出力CSV:   k v_rec u spike     (1ステップ1行)
`timescale 1ns/1ps
module tb_neuron_core;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    logic tick = 1'b0;
    logic mode = 1'b0;
    logic signed [31:0] I_in = 32'sd0;
    logic [1:0] preset = 2'd0;
    logic signed [31:0] pa, pb, pc, pd;
    logic signed [31:0] v_rec, u_out;
    logic spike, valid;

    preset_rom u_rom (.sel(preset), .a(pa), .b(pb), .c(pc), .d(pd));
    neuron_core dut (
        .clk(clk), .rst(rst), .tick(tick), .mode(mode), .I_in(I_in),
        .pa(pa), .pb(pb), .pc(pc), .pd(pd),
        .v_rec(v_rec), .u_out(u_out), .spike(spike), .valid(valid)
    );

    integer mode_i, preset_i, Iq, steps, on_step, k, fd;
    reg [8*256-1:0] fname;

    initial begin
        mode_i = 0; preset_i = 0; Iq = 655360; steps = 1200; on_step = 80;
        fname = "core_out.csv";
        void'($value$plusargs("mode=%d", mode_i));
        void'($value$plusargs("preset=%d", preset_i));
        void'($value$plusargs("Iq=%d", Iq));
        void'($value$plusargs("steps=%d", steps));
        void'($value$plusargs("on=%d", on_step));
        void'($value$plusargs("out=%s", fname));
        mode = mode_i[0];
        preset = preset_i[1:0];
        fd = $fopen(fname, "w");

        repeat (5) @(posedge clk);
        #1 rst = 1'b0;
        repeat (2) @(posedge clk);

        for (k = 0; k < steps; k = k + 1) begin
            #1;
            I_in = (k < on_step) ? 32'sd0 : Iq;
            tick = 1'b1;
            @(posedge clk); #1;
            tick = 1'b0;
            while (!valid) begin @(posedge clk); #1; end
            $fdisplay(fd, "%0d %0d %0d %0d", k, v_rec, u_out, spike);
        end
        $fclose(fd);
        $finish;
    end

    initial begin
        #2000000000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
