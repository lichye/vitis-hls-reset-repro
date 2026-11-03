`timescale 1ns/1ps
`default_nettype none

module tb_startup;
    reg ap_clk = 0;
    reg ap_rst = 1;
    reg ap_start = 0;
    wire ap_done, ap_ready, ap_idle;
    wire [9:0] a_address0, a_address1, b_address0, c_address0;
    wire a_ce0, a_we0, a_ce1, b_ce0, c_ce0;
    wire [31:0] a_d0;
    reg [31:0] a_q1 = 0;
    reg [31:0] a_read_stage = 0;
    reg a_read_pending = 0;
    reg [31:0] b_q0 = 1;
    reg [31:0] c_q0 = 2;
    reg [31:0] a [0:1023];
    integer cycles = 0;
    integer k;
    integer seed;

    array_madd_top dut (
        .ap_clk(ap_clk), .ap_rst(ap_rst), .ap_start(ap_start),
        .ap_done(ap_done), .ap_ready(ap_ready), .ap_idle(ap_idle),
        .a_address0(a_address0), .a_ce0(a_ce0), .a_we0(a_we0), .a_d0(a_d0),
        .a_address1(a_address1), .a_ce1(a_ce1), .a_q1(a_q1),
        .b_address0(b_address0), .b_ce0(b_ce0), .b_q0(b_q0),
        .c_address0(c_address0), .c_ce0(c_ce0), .c_q0(c_q0));

    always #5 ap_clk = ~ap_clk;

    // The HLS schedule gives A two-cycle reads, and B/C one-cycle reads.
    // B and C contain only 1 and 2.
    always @(posedge ap_clk) begin
        a_read_pending <= a_ce1;
        if (a_ce1) a_read_stage <= a[a_address1];
        if (a_read_pending) a_q1 <= a_read_stage;
        if (b_ce0) b_q0 <= 32'd1;
        if (c_ce0) c_q0 <= 32'd2;
        if (a_ce0 && a_we0) a[a_address0] <= a_d0;
    end

    initial begin
        for (k = 0; k < 1024; k = k + 1) a[k] = 0;
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        $dumpfile($sformatf("seed%0d.vcd", seed));
        $dumpvars(0, tb_startup);

        // Deposit a legal power-up value once, before reset clocks.
        // Never force a signal or alter the synthesized RTL's reset logic.
        #1;
`ifdef FRAMEWORK
        dut.grp_array_madd_fu_24.ap_loop_exit_ready_pp0_iter1_reg = 0;
        dut.grp_array_madd_fu_24.ap_loop_exit_ready_pp0_iter2_reg = 0;
        dut.grp_array_madd_fu_24.ap_loop_exit_ready_pp0_iter3_reg = 0;
        dut.grp_array_madd_fu_24.ap_loop_exit_ready_pp0_iter4_reg = seed;
`else
        dut.ap_loop_exit_ready_pp0_iter1_reg = 0;
        dut.ap_loop_exit_ready_pp0_iter2_reg = 0;
        dut.ap_loop_exit_ready_pp0_iter3_reg = 0;
        dut.ap_loop_exit_ready_pp0_iter4_reg = 0;
        dut.ap_loop_exit_ready_pp0_iter5_reg = seed;
        dut.ap_condition_exit_pp0_iter0_stage1_pp0_iter1_reg = 0;
        dut.ap_condition_exit_pp0_iter0_stage1_pp0_iter2_reg = 0;
        dut.ap_condition_exit_pp0_iter0_stage1_pp0_iter3_reg = 0;
        dut.ap_condition_exit_pp0_iter0_stage1_pp0_iter4_reg = 0;
        dut.ap_condition_exit_pp0_iter0_stage1_pp0_iter5_reg = seed;
`endif

        repeat (2) @(negedge ap_clk);
        ap_rst = 0;
        ap_start = 1;
        repeat (2200) begin
            @(negedge ap_clk);
            cycles = cycles + 1;
            if (ap_done === 1'b1) begin
                // Let a simultaneous final BRAM write commit before checking.
                @(posedge ap_clk);
                #1;
                $display("ap_done at cycle %0d", cycles);
                $display("a[0..7] = %0d %0d %0d %0d %0d %0d %0d %0d",
                         a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
                $finish;
            end
            if (ap_ready === 1'b1) ap_start = 0;
        end
        $display("no ap_done within 2200 cycles");
        $finish;
    end
endmodule

`default_nettype wire
