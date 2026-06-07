//==========================================================================
// deck_memory.sv  -  52 x 4-bit ROM of raw card ranks.
// Holds four copies each of ranks 1..13 (Ace..King). Address order is fixed;
// randomness comes from the shuffler addressing it. Combinational read.
//==========================================================================
module deck_memory (
    input  logic [5:0] addr,        // 0..51
    output logic [3:0] card_val     // 1..13
);
    logic [3:0] mem [0:51];

    initial begin
        for (int i = 0; i < 52; i++)
            mem[i] = 4'((i % 13) + 1);
    end

    assign card_val = mem[addr];
endmodule
