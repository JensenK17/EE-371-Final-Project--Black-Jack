//==========================================================================
// tb_game.sv
// Integration test of the game core: game_controller + hand_registers +
// balance_tracker, with the real shuffle_fifo replaced by a testbench-driven
// deck so exact card sequences can be scripted. Verifies stand-win, player
// bust, double-down, split (both win), and split-rejected-on-non-pair, by
// checking the running balance after each round.
//
// Deck draw order per round: [0]=playerA, [1]=dealerUp, [2]=playerA,
// [3]=dealerHole, [4..]=subsequent draws (player hits / split cards, then
// dealer auto-draws).
//==========================================================================
`timescale 1ns/1ps
module tb_game;
    localparam int MC = 11;

    logic clk = 0, rst = 0;
    logic hit = 0, stand = 0, dbl = 0, split = 0;
    always #10 clk = ~clk;

    // ---- scripted deck model (mimics shuffle_fifo draw handshake) ----
    logic [3:0] deck [0:51];
    logic [5:0] rd = 0;
    logic [3:0] next_card;
    assign next_card = deck[rd];

    // ---- DUT interconnect ----
    logic       take_card, split_en;
    logic [1:0] load_target;
    logic [MC*4-1:0] cards_a, cards_b, cards_d;
    logic [3:0] count_a, count_b, count_d;
    logic [7:0] total_a, total_b, total_d;
    logic       bust_a, bust_b, bust_d, bj_a, bj_b, bj_d, pair_match;
    logic       bal_strobe; logic signed [7:0] bal_delta;
    logic [7:0] balance;
    logic       reveal_hole, split_active, active_hand, round_over;
    logic [1:0] result_a, result_b;
    logic [6:0] h0,h1,h2,h3,h4,h5; logic [9:0] ledr;

    always_ff @(posedge clk)
        if (rst) rd <= 0; else if (take_card) rd <= rd + 1;

    game_controller u_fsm (
        .clk(clk), .rst(rst),
        .hit(hit), .stand(stand), .double(dbl), .split(split),
        .shuffle_done(1'b1),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .bust_a(bust_a), .bust_b(bust_b), .bust_d(bust_d),
        .pair_match(pair_match), .balance(balance),
        .take_card(take_card), .load_target(load_target), .split_en(split_en),
        .bal_strobe(bal_strobe), .bal_delta(bal_delta),
        .reveal_hole(reveal_hole), .split_active(split_active),
        .active_hand(active_hand), .round_over(round_over),
        .result_a(result_a), .result_b(result_b));

    hand_registers #(.MAX_CARDS(MC)) u_hands (
        .clk(clk), .rst(rst),
        .load_en(take_card), .load_target(load_target), .load_val(next_card),
        .split_en(split_en),
        .cards_a(cards_a), .cards_b(cards_b), .cards_d(cards_d),
        .count_a(count_a), .count_b(count_b), .count_d(count_d),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .bust_a(bust_a), .bust_b(bust_b), .bust_d(bust_d),
        .bj_a(bj_a), .bj_b(bj_b), .bj_d(bj_d), .pair_match(pair_match));

    balance_tracker u_bal (
        .clk(clk), .rst(rst), .bal_strobe(bal_strobe), .bal_delta(bal_delta),
        .round_over(round_over), .result_a(result_a), .result_b(result_b),
        .balance(balance),
        .HEX0(h0), .HEX1(h1), .HEX2(h2), .HEX3(h3), .HEX4(h4), .HEX5(h5),
        .LEDR(ledr));

    int errors = 0;

    task automatic clear_deck();
        for (int i = 0; i < 52; i++) deck[i] = 4'd5;
    endtask

    task automatic newround();
        @(negedge clk); rst = 1;
        @(posedge clk);            // FSM samples rst
        @(negedge clk); rst = 0;
        repeat (8) @(posedge clk); // SHUF->BET->DEAL(4)-> in PLAYER_A
    endtask

    task automatic tap_hit();   @(negedge clk) hit=1;   @(negedge clk) hit=0;   repeat(3) @(posedge clk); endtask
    task automatic tap_stand(); @(negedge clk) stand=1; @(negedge clk) stand=0; @(posedge clk); endtask
    task automatic tap_dbl();   @(negedge clk) dbl=1;   @(negedge clk) dbl=0;   @(posedge clk); endtask
    task automatic tap_split(); @(negedge clk) split=1; @(negedge clk) split=0; repeat(5) @(posedge clk); endtask

    task automatic finish();
        int g; g = 0;
        while (!round_over) begin
            @(posedge clk); g++;
            if (g > 300) begin $error("round did not complete"); errors++; break; end
        end
        @(posedge clk); // let final payout settle
    endtask

    task automatic check_bal(input string name, input int exp);
        if (balance !== 8'(exp)) begin
            $error("%-26s balance=%0d (exp %0d)", name, balance, exp);
            errors++;
        end else begin
            $display("  ok  %-26s balance=%0d", name, balance);
        end
    endtask

    initial begin
        clear_deck();

        // --- S1: stand, player 20 vs dealer 17 -> win. 5 -1 +2 = 6 ---
        deck[0]=10; deck[1]=10; deck[2]=10; deck[3]=7;
        newround();
        tap_stand();
        finish();
        check_bal("S1 stand win", 6);

        // --- S2: player 17, hit 10 -> bust. 6 -1 = 5 ---
        clear_deck();
        deck[0]=10; deck[1]=9; deck[2]=7; deck[3]=9; deck[4]=10;
        newround();
        tap_hit();
        finish();
        check_bal("S2 player bust", 5);

        // --- S3: 5+6=11, double -> 21 vs dealer 18 -> win. 5 -1 -1 +4 = 7 ---
        clear_deck();
        deck[0]=5; deck[1]=10; deck[2]=6; deck[3]=8; deck[4]=10;
        newround();
        tap_dbl();
        finish();
        check_bal("S3 double win", 7);

        // --- S4: split 8,8; both 13; dealer busts (12->22). 7 -1 -1 +2 +2 = 9 ---
        clear_deck();
        deck[0]=8; deck[1]=6; deck[2]=8; deck[3]=6; deck[4]=5; deck[5]=5; deck[6]=10;
        newround();
        tap_split();
        tap_stand();                       // hand A
        while (!active_hand) @(posedge clk); // wait for hand B
        tap_stand();                       // hand B
        finish();
        check_bal("S4 split both win", 9);
        if (split_active !== 1'b1) begin $error("S4 split_active should be 1"); errors++; end

        // --- S5: split pressed on non-pair (10,7) -> ignored; stand; win.
        //         9 -1 +2 = 10, and split_active must stay 0 ---
        clear_deck();
        deck[0]=10; deck[1]=9; deck[2]=7; deck[3]=7; deck[4]=10;
        newround();
        tap_split();                       // illegal: not a pair -> ignored
        if (split_active !== 1'b0) begin $error("S5 split should be rejected"); errors++; end
        tap_stand();
        finish();
        check_bal("S5 non-pair split reject", 10);

        if (errors == 0) $display("\nTB_GAME: ALL PASS");
        else             $display("\nTB_GAME: %0d FAILURES", errors);
        $finish;
    end

    initial begin
        #5_000_000; $error("global timeout"); $finish;
    end
endmodule
