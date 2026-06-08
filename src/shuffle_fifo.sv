//==========================================================================
// shuffle_fifo.sv
// LFSR-driven Fisher-Yates-style shuffler + draw FIFO.
//
// On `rst` it clears its state and (over many cycles) fills a 52-entry array
// with the deck in a random order: a free-running LFSR proposes deck
// addresses; a 52-bit `used` mask rejects already-taken addresses until all
// 52 unique cards have been enqueued (`shuffle_done`). During play, `draw_req`
// pops the front; `next_card` is the card currently at the head.
//
// Worst-case fill is a few hundred cycles, far less than one 60 Hz frame.
//==========================================================================
module shuffle_fifo (
    input  logic       clk,
    input  logic       rst,        // new round: reshuffle
    input  logic       draw_req,   // pop the front card

    output logic [3:0] next_card,  // card at head of FIFO
    output logic       shuffle_done,
    output logic       empty
);
    // ---- free-running randomness ----
    logic [15:0] rnd;
    lfsr #(.WIDTH(16)) u_lfsr (.clk(clk), .en(1'b1), .value(rnd));

    // ---- deck ROM ----
    logic [5:0] deck_addr;
    logic [3:0] deck_val;
    deck_memory u_deck (.addr(deck_addr), .card_val(deck_val));

    // ---- storage ----
    logic [3:0]  fifo [0:51];
    logic [51:0] used;
    logic [6:0]  fill;     // entries written, 0..52
    logic [6:0]  rd_ptr;   // entries drawn,   0..52

    typedef enum logic {SH_RUN, SH_READY} state_t;
    state_t state = SH_READY;

    logic [5:0] cand;
    assign cand      = rnd[5:0];
    assign deck_addr = cand;

    assign next_card    = fifo[rd_ptr[5:0]];
    assign empty        = (rd_ptr >= fill);
    assign shuffle_done = (state == SH_READY);

    always_ff @(posedge clk) begin
        if (rst) begin
            state  <= SH_RUN;
            fill   <= '0;
            rd_ptr <= '0;
            used   <= '0;
        end else begin
            unique case (state)
                SH_RUN: begin
                    if (fill < 7'd52) begin
                        if ((cand < 6'd52) && !used[cand]) begin
                            fifo[fill[5:0]] <= deck_val;
                            used[cand]      <= 1'b1;
                            fill            <= fill + 7'd1;
                        end
                    end else begin
                        state <= SH_READY;
                    end
                end
                SH_READY: begin
                    if (draw_req && !empty)
                        rd_ptr <= rd_ptr + 7'd1;
                end
            endcase
        end
    end
endmodule
