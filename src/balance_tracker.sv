//==========================================================================
// balance_tracker.sv
// Owns the player's dollar balance. Starts at $5. On a new round (rst) it
// tops back up to $5 only if it had hit $0. Applies signed `bal_delta` on each
// `bal_strobe` (debits from betting, credits from payouts), clamped at 0.
//
// Drives the balance as two decimal digits on HEX1:HEX0 (HEX2..HEX5 blank)
// and shows the most recent round result(s) on LEDR when `round_over`.
//==========================================================================
module balance_tracker (
    input  logic              clk,
    input  logic              rst,
    input  logic              bal_strobe,
    input  logic signed [7:0] bal_delta,

    input  logic              round_over,
    input  logic [1:0]        result_a,    // 0 none,1 win,2 lose,3 push
    input  logic [1:0]        result_b,

    output logic [7:0]        balance,
    output logic [6:0]        HEX0,
    output logic [6:0]        HEX1,
    output logic [6:0]        HEX2,
    output logic [6:0]        HEX3,
    output logic [6:0]        HEX4,
    output logic [6:0]        HEX5,
    output logic [9:0]        LEDR
);
    localparam logic [1:0] R_WIN  = 2'd1;
    localparam logic [1:0] R_LOSE = 2'd2;
    localparam logic [1:0] R_PUSH = 2'd3;

    initial balance = 8'd5;

    logic signed [9:0] next;
    always_comb next = $signed({2'b00, balance}) + $signed({{2{bal_delta[7]}}, bal_delta});

    always_ff @(posedge clk) begin
        if (rst) begin
            if (balance == 8'd0) balance <= 8'd5;
        end else if (bal_strobe) begin
            balance <= (next < 0) ? 8'd0 : next[7:0];
        end
    end

    //----- HEX: two decimal digits (ones on HEX0, tens on HEX1) -----------
    logic [3:0] ones, tens;
    assign ones = balance % 8'd10;
    assign tens = (balance / 8'd10) % 8'd10;

    hex_decoder u_h0 (.value(ones), .seg(HEX0));
    hex_decoder u_h1 (.value(tens), .seg(HEX1));
    assign HEX2 = 7'h7F;
    assign HEX3 = 7'h7F;
    assign HEX4 = 7'h7F;
    assign HEX5 = 7'h7F;

    //----- LEDR result indicators -----------------------------------------
    // [2:0] = hand A {win,push,lose}, [5:3] = hand B {win,push,lose}
    always_comb begin
        LEDR = 10'b0;
        if (round_over) begin
            LEDR[0] = (result_a == R_WIN);
            LEDR[1] = (result_a == R_PUSH);
            LEDR[2] = (result_a == R_LOSE);
            LEDR[3] = (result_b == R_WIN);
            LEDR[4] = (result_b == R_PUSH);
            LEDR[5] = (result_b == R_LOSE);
        end
    end
endmodule
