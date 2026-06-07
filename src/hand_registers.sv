//==========================================================================
// hand_registers.sv
// Holds the three hands - player A, player B (split only), dealer - each a
// packed array of up to MAX_CARDS ranks plus a card count. Appends a drawn
// card to the hand selected by `load_target`, and supports the split move
// (relocate player A's 2nd card to player B). Instantiates hand_total per
// hand and exposes pair_match for split legality.
//
//   load_target: 0 = player A, 1 = player B, 2 = dealer
//==========================================================================
module hand_registers #(
    parameter int MAX_CARDS = 11
) (
    input  logic       clk,
    input  logic       rst,          // new round: clear all hands
    input  logic       load_en,      // append load_val to load_target
    input  logic [1:0] load_target,
    input  logic [3:0] load_val,
    input  logic       split_en,     // move A[1] -> B[0]; counts A=1, B=1

    output logic [MAX_CARDS*4-1:0] cards_a,
    output logic [MAX_CARDS*4-1:0] cards_b,
    output logic [MAX_CARDS*4-1:0] cards_d,
    output logic [3:0]             count_a,
    output logic [3:0]             count_b,
    output logic [3:0]             count_d,
    output logic [7:0]             total_a,
    output logic [7:0]             total_b,
    output logic [7:0]             total_d,
    output logic                   bust_a,
    output logic                   bust_b,
    output logic                   bust_d,
    output logic                   bj_a,
    output logic                   bj_b,
    output logic                   bj_d,
    output logic                   pair_match
);
    localparam logic [1:0] HAND_A = 2'd0;
    localparam logic [1:0] HAND_B = 2'd1;
    localparam logic [1:0] HAND_D = 2'd2;

    initial begin
        cards_a = '0; cards_b = '0; cards_d = '0;
        count_a = '0; count_b = '0; count_d = '0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            cards_a <= '0; cards_b <= '0; cards_d <= '0;
            count_a <= '0; count_b <= '0; count_d <= '0;
        end else if (split_en) begin
            // Move player A's second card to a fresh player B.
            cards_b[3:0] <= cards_a[7:4];
            count_a      <= 4'd1;
            count_b      <= 4'd1;
        end else if (load_en) begin
            unique case (load_target)
                HAND_A: begin
                    cards_a[count_a*4 +: 4] <= load_val;
                    count_a                 <= count_a + 4'd1;
                end
                HAND_B: begin
                    cards_b[count_b*4 +: 4] <= load_val;
                    count_b                 <= count_b + 4'd1;
                end
                default: begin
                    cards_d[count_d*4 +: 4] <= load_val;
                    count_d                 <= count_d + 4'd1;
                end
            endcase
        end
    end

    // pair_match on raw rank of the first two player-A cards.
    assign pair_match = (count_a >= 4'd2) && (cards_a[3:0] == cards_a[7:4]);

    hand_total #(.MAX_CARDS(MAX_CARDS)) u_ta (
        .cards_flat(cards_a), .count(count_a),
        .total(total_a), .is_bust(bust_a), .is_blackjack(bj_a));

    hand_total #(.MAX_CARDS(MAX_CARDS)) u_tb (
        .cards_flat(cards_b), .count(count_b),
        .total(total_b), .is_bust(bust_b), .is_blackjack(bj_b));

    hand_total #(.MAX_CARDS(MAX_CARDS)) u_td (
        .cards_flat(cards_d), .count(count_d),
        .total(total_d), .is_bust(bust_d), .is_blackjack(bj_d));
endmodule
