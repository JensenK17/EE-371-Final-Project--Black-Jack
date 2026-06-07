//==========================================================================
// hand_total.sv  -  combinational blackjack hand evaluator.
//
// Cards are packed 4-bit ranks (1..13). Scoring: ranks 10..13 count as 10,
// rank 1 (Ace) counts as 11 then is reduced to 1 (subtract 10) as needed to
// avoid busting. Only the first `count` cards are summed.
//==========================================================================
module hand_total #(
    parameter int MAX_CARDS = 11
) (
    input  logic [MAX_CARDS*4-1:0] cards_flat,
    input  logic [3:0]             count,
    output logic [7:0]             total,
    output logic                   is_bust,
    output logic                   is_blackjack
);
    always_comb begin
        int sum;
        int aces;
        logic [3:0] v;

        sum  = 0;
        aces = 0;
        v    = '0;

        for (int i = 0; i < MAX_CARDS; i++) begin
            if (i < int'(count)) begin
                v = cards_flat[i*4 +: 4];
                if (v == 4'd1) begin
                    aces += 1;
                    sum  += 11;
                end else if (v >= 4'd10) begin
                    sum += 10;
                end else begin
                    sum += int'(v);
                end
            end
        end

        // Demote aces from 11 to 1 while busting and aces remain.
        for (int k = 0; k < MAX_CARDS; k++) begin
            if (sum > 21 && aces > 0) begin
                sum  -= 10;
                aces -= 1;
            end
        end

        total        = 8'(sum);
        is_bust      = (sum > 21);
        is_blackjack = (count == 4'd2) && (sum == 21);
    end
endmodule
