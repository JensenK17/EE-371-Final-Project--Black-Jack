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

    string seq;

    initial begin
        $display("============================================================");
        $display(" TB_SHUFFLE_FIFO : deck shuffle + draw coverage");
        $display("============================================================");
        for (int r = 1; r <= 13; r++) hist[r] = 0;

        // let the LFSR spin a while, then shuffle
        repeat (37) @(posedge clk);
        @(negedge clk) rst = 1;
        @(negedge clk) rst = 0;

        // wait for the shuffle to complete
        wait (shuffle_done);
        @(posedge clk);
        $display("[PASS] shuffle_done asserted");

        // draw all 52
        seq = "";
        for (int i = 0; i < 52; i++) begin
            if (empty) begin $error("FIFO empty at draw %0d", i); errors++; end
            if (next_card < 1 || next_card > 13) begin
                $error("bad rank %0d at draw %0d", next_card, i); errors++;
            end else begin
                hist[next_card]++;
            end
            seq = {seq, $sformatf("%0d ", next_card)};
            @(negedge clk) draw = 1;
            @(negedge clk) draw = 0;
        end
        $display("       drawn order: %s", seq);

        for (int r = 1; r <= 13; r++) begin
            if (hist[r] != 4) begin
                $error("[FAIL] rank %0d appeared %0d times (exp 4)", r, hist[r]);
                errors++;
            end else begin
                $display("[PASS] rank %2d appears 4 times", r);
            end
        end

        $display("------------------------------------------------------------");
        if (errors == 0)
            $display(" TB_SHUFFLE_FIFO: ALL PASS (52 cards, 4x each rank)");
        else
            $display(" TB_SHUFFLE_FIFO: %0d FAILURE(S)", errors);
        $display("============================================================");
        $finish;
    end

    initial begin
        #2_000_000;
        $error("timeout"); $finish;
    end
endmodule
