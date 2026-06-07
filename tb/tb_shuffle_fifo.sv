//==========================================================================
// tb_shuffle_fifo.sv  -  shuffle a deck, draw all 52 cards, and confirm the
// multiset is exactly four copies of each rank 1..13 (no repeats/omissions).
//==========================================================================
`timescale 1ns/1ps
module tb_shuffle_fifo;
    logic       clk = 0, rst = 0, draw = 0;
    logic [3:0] next_card;
    logic       shuffle_done, empty;
    int         hist [1:13];
    int         errors = 0;

    always #10 clk = ~clk;   // 50 MHz

    shuffle_fifo dut (
        .clk(clk), .rst(rst), .draw_req(draw),
        .next_card(next_card), .shuffle_done(shuffle_done), .empty(empty));

    initial begin
        for (int r = 1; r <= 13; r++) hist[r] = 0;

        // let the LFSR spin a while, then shuffle
        repeat (37) @(posedge clk);
        @(negedge clk) rst = 1;
        @(negedge clk) rst = 0;

        // wait for the shuffle to complete
        wait (shuffle_done);
        @(posedge clk);

        // draw all 52
        for (int i = 0; i < 52; i++) begin
            if (empty) begin $error("FIFO empty at draw %0d", i); errors++; end
            if (next_card < 1 || next_card > 13) begin
                $error("bad rank %0d at draw %0d", next_card, i); errors++;
            end else begin
                hist[next_card]++;
            end
            @(negedge clk) draw = 1;
            @(negedge clk) draw = 0;
        end

        for (int r = 1; r <= 13; r++) begin
            if (hist[r] != 4) begin
                $error("rank %0d appeared %0d times (exp 4)", r, hist[r]);
                errors++;
            end
        end

        if (errors == 0) $display("\nTB_SHUFFLE_FIFO: ALL PASS (52 unique, 4x each)");
        else             $display("\nTB_SHUFFLE_FIFO: %0d FAILURES", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $error("timeout"); $finish;
    end
endmodule
