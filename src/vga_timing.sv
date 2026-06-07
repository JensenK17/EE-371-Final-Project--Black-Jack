//==========================================================================
// vga_timing.sv  -  640x480 @ 60 Hz timing from CLOCK_50.
// Generates a 25 MHz pixel clock by dividing CLOCK_50 by two and runs the
// horizontal/vertical counters in that domain. Outputs pixel coordinates,
// active-video flag, and active-low sync. (A divided clock is adequate here;
// swap in a PLL if the monitor refuses to lock.)
//==========================================================================
module vga_timing (
    input  logic       clk50,
    output logic       clk25,
    output logic [9:0] x,
    output logic [9:0] y,
    output logic       active,
    output logic       hsync,
    output logic       vsync
);
    // 640x480@60 standard timing (pixel clock 25.175 MHz)
    localparam int H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    localparam int V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33;
    localparam int H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800
    localparam int V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    logic pix = 1'b0;
    always_ff @(posedge clk50) pix <= ~pix;
    assign clk25 = pix;

    logic [9:0] hc = '0, vc = '0;
    always_ff @(posedge pix) begin
        if (hc == 10'(H_TOTAL - 1)) begin
            hc <= '0;
            vc <= (vc == 10'(V_TOTAL - 1)) ? 10'd0 : vc + 10'd1;
        end else begin
            hc <= hc + 10'd1;
        end
    end

    assign x      = hc;
    assign y      = vc;
    assign active = (hc < 10'(H_VISIBLE)) && (vc < 10'(V_VISIBLE));
    assign hsync  = ~((hc >= 10'(H_VISIBLE + H_FRONT)) &&
                      (hc <  10'(H_VISIBLE + H_FRONT + H_SYNC)));
    assign vsync  = ~((vc >= 10'(V_VISIBLE + V_FRONT)) &&
                      (vc <  10'(V_VISIBLE + V_FRONT + V_SYNC)));
endmodule
