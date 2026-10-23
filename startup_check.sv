`default_nettype none
module startup_check(input wire ap_clk);
    reg [1:0] reset_cycles = 0;
    wire ap_rst = reset_cycles < 2;
    reg request_pending = 1;
    wire ap_start = !ap_rst && request_pending;
    wire ap_done, ap_ready, ap_idle;
    wire [9:0] a_address0, a_address1, b_address0, c_address0;
    wire a_ce0, a_we0, a_ce1, b_ce0, c_ce0;
    wire [31:0] a_d0;
    reg saw_write = 0;
    // A=0, B=1, C=2 obey all source preconditions. Before the first write,
    // constant read responses are a valid synchronous-memory execution.
    array_madd_top dut (
        .ap_clk(ap_clk), .ap_rst(ap_rst), .ap_start(ap_start),
        .ap_done(ap_done), .ap_ready(ap_ready), .ap_idle(ap_idle),
        .a_address0(a_address0), .a_ce0(a_ce0), .a_we0(a_we0), .a_d0(a_d0),
        .a_address1(a_address1), .a_ce1(a_ce1), .a_q1(32'd0),
        .b_address0(b_address0), .b_ce0(b_ce0), .b_q0(32'd1),
        .c_address0(c_address0), .c_ce0(c_ce0), .c_q0(32'd2));
    always @(posedge ap_clk) begin
        if (reset_cycles < 2) reset_cycles <= reset_cycles + 1'b1;
        if (!ap_rst && ap_ready) request_pending <= 0;
        if (ap_rst) saw_write <= 0;
        else if (a_ce0 && a_we0) saw_write <= 1;
        if (!ap_rst) done_after_write: assert (!ap_done || saw_write);
    end
endmodule
`default_nettype wire
