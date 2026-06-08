//==========================================================================
// tb_hand_total.sv  -  directed checks of the blackjack hand evaluator,
// focused on the Ace = 1/11 rule and face-cards-as-10.
//==========================================================================
`timescale 1ns/1ps
module tb_hand_total;
    localparam int MC = 11;

    logic [MC*4-1:0] cards;
    logic [3:0]      count;
    logic [7:0]      total;
    logic            bust, bj;
    int              errors = 0;

    hand_total #(.MAX_CARDS(MC)) dut (
        .cards_flat(cards), .count(count),
        .total(total), .is_bust(bust), .is_blackjack(bj));

    // pack up to 5 ranks
    task automatic seth(input int n, input int c0, input int c1, input int c2,
                        input int c3, input int c4);
        cards = '0;
        cards[3:0]   = 4'(c0);
        cards[7:4]   = 4'(c1);
        cards[11:8]  = 4'(c2);
        cards[15:12] = 4'(c3);
        cards[19:16] = 4'(c4);
        count = 4'(n);
        #1;
    endtask

    task automatic chk(input string name, input int exp_total,
                       input bit exp_bust);
        if (total !== 8'(exp_total) || bust !== exp_bust) begin
            $error("[FAIL] %-22s total=%0d bust=%0b (exp %0d/%0b)",
                   name, total, bust, exp_total, exp_bust);
            errors++;
        end else begin
            $display("[PASS] %-22s total=%2d bust=%0b", name, total, bust);
        end
    endtask

    task automatic chk_bj(input string name, input bit exp_bj);
        if (bj !== exp_bj) begin
            $error("[FAIL] %-22s blackjack=%0b (exp %0b)", name, bj, exp_bj);
            errors++;
        end else begin
            $display("[PASS] %-22s blackjack=%0b", name, bj);
        end
    endtask

    initial begin
        $display("============================================================");
        $display(" TB_HAND_TOTAL : ace 1/11 rule + face-cards-as-10");
        $display("============================================================");
        seth(2, 1, 13, 0, 0, 0);  chk("A+K (blackjack)",   21, 0);
        chk_bj("A+K is blackjack", 1);
        seth(2, 1, 1, 0, 0, 0);   chk("A+A",               12, 0);
        seth(3, 1, 1, 9, 0, 0);   chk("A+A+9",             21, 0);
        seth(3, 1, 1, 10, 0, 0);  chk("A+A+10",            12, 0);
        seth(2, 10, 11, 0, 0, 0); chk("10+J",              20, 0);
        seth(3, 13, 12, 5, 0, 0); chk("K+Q+5 bust",        25, 1);
        seth(4, 1, 5, 5, 1, 0);   chk("A+5+5+A",           12, 0);
        seth(5, 1, 2, 3, 4, 1);   chk("A+2+3+4+A",         21, 0);
        seth(2, 1, 9, 0, 0, 0);   chk("A+9 (soft 20)",     20, 0);
        seth(3, 1, 9, 5, 0, 0);   chk("A+9+5",             15, 0);

        $display("------------------------------------------------------------");
        if (errors == 0) $display(" TB_HAND_TOTAL: ALL PASS");
        else             $display(" TB_HAND_TOTAL: %0d FAILURE(S)", errors);
        $display("============================================================");
        $finish;
    end
endmodule
