//==========================================================================
// synchronizer.sv  -  two flip-flop synchronizer for an async input.
//==========================================================================
module synchronizer (
    input  logic clk,
    input  logic d,
    output logic q
);
    logic meta;
    always_ff @(posedge clk) begin
        meta <= d;
        q    <= meta;
    end
endmodule
