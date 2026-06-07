//==========================================================================
// debouncer.sv
// Debounces one (already-synchronized) active-high input. Requires the input
// to hold a new value for DEB clock cycles before the internal "stable" copy
// follows it. Emits a single-cycle `pulse` on each clean rising edge (press)
// and exposes the debounced `level`.
//
// DEB defaults to ~10 ms at 50 MHz; testbenches override it with a tiny value.
//==========================================================================
module debouncer #(
    parameter int DEB = 500_000
) (
    input  logic clk,
    input  logic in,        // synchronized, active-high
    output logic pulse,     // 1-cycle pulse on rising edge of stable
    output logic level      // debounced level
);
    localparam int CW = (DEB <= 1) ? 1 : $clog2(DEB);

    logic [CW-1:0] cnt   = '0;
    logic          stable   = 1'b0;
    logic          stable_d = 1'b0;

    always_ff @(posedge clk) begin
        if (in == stable) begin
            cnt <= '0;
        end else begin
            cnt <= cnt + 1'b1;
            if (cnt == CW'(DEB - 1)) begin
                stable <= in;
                cnt    <= '0;
            end
        end
        stable_d <= stable;
    end

    assign pulse = stable & ~stable_d;
    assign level = stable;
endmodule
