//==========================================================================
// input_conditioning.sv
// Synchronizes + debounces the player controls and produces single-cycle
// command pulses. KEYs are active-low on the board, so they are inverted to
// active-high "pressed" before debouncing. SW[9] produces a one-cycle
// new-round pulse (rst) on its rising edge.
//
//   KEY[3] = HIT   KEY[2] = DOUBLE   KEY[1] = SPLIT   KEY[0] = STAND
//==========================================================================
module input_conditioning #(
    parameter int DEB = 500_000
) (
    input  logic       clk,
    input  logic [3:0] KEY,     // active-low pushbuttons
    input  logic       sw9,     // reset / new-round switch

    output logic       hit,
    output logic       stand,
    output logic       double,
    output logic       split,
    output logic       rst       // 1-cycle pulse: shuffle + new round
);
    // ---- pressed (active-high) views of the keys ----
    logic key_hit, key_stand, key_double, key_split;
    assign key_hit    = ~KEY[3];
    assign key_stand  = ~KEY[0];
    assign key_double = ~KEY[2];
    assign key_split  = ~KEY[1];

    // ---- synchronize ----
    logic s_hit, s_stand, s_double, s_split, s_sw9;
    synchronizer u_s0 (.clk, .d(key_hit),    .q(s_hit));
    synchronizer u_s1 (.clk, .d(key_stand),  .q(s_stand));
    synchronizer u_s2 (.clk, .d(key_double), .q(s_double));
    synchronizer u_s3 (.clk, .d(key_split),  .q(s_split));
    synchronizer u_s4 (.clk, .d(sw9),        .q(s_sw9));

    // ---- debounce + edge-detect ----
    debouncer #(.DEB(DEB)) u_d0 (.clk, .in(s_hit),    .pulse(hit),    .level());
    debouncer #(.DEB(DEB)) u_d1 (.clk, .in(s_stand),  .pulse(stand),  .level());
    debouncer #(.DEB(DEB)) u_d2 (.clk, .in(s_double), .pulse(double), .level());
    debouncer #(.DEB(DEB)) u_d3 (.clk, .in(s_split),  .pulse(split),  .level());
    debouncer #(.DEB(DEB)) u_d4 (.clk, .in(s_sw9),    .pulse(rst),    .level());
endmodule
