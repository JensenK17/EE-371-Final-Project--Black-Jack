//==========================================================================
// lfsr.sv  -  16-bit maximal-length Fibonacci LFSR (taps 16,14,13,11).
// Free-running: it advances every cycle it is enabled and is NOT reseeded on
// the game reset, so the state captured when a shuffle begins depends on how
// long the board has been running -> a different deck order each round.
//==========================================================================
module lfsr #(
    parameter          WIDTH = 16,
    parameter [15:0]   SEED  = 16'hACE1
) (
    input  logic             clk,
    input  logic             en,
    output logic [WIDTH-1:0] value
);
    logic [WIDTH-1:0] r = SEED[WIDTH-1:0];
    logic             fb;

    assign fb = r[15] ^ r[13] ^ r[12] ^ r[10];

    always_ff @(posedge clk)
        if (en) r <= {r[WIDTH-2:0], fb};

    assign value = r;
endmodule
