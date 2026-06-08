//==========================================================================
// vga_timing.sv  -  640x480 @ 60 Hz timing from CLOCK_50.
//
// Single clock domain: ALL sequential logic is clocked by CLOCK_50. A toggle
// flip-flop (`pix`) divides it to a clean, REGISTERED 25 MHz pixel clock that
// is driven straight out to the ADV7123 as VGA_CLK. The pixel counters advance
// once per VGA_CLK period via a clock-enable rather than being clocked by the
// divided signal -- so there is no logic-generated clock domain for the fitter
// to mis-route, which is what a remote VGA frame-grabber (LabsLand) needs to
// lock onto the signal.
//
// Phase: counters advance on the CLOCK_50 edge where `pix` is high (pix 1->0),
// so the new pixel is stable BEFORE the next rising edge of VGA_CLK (pix 0->1)
// at which the DAC latches the RGB data.
//==========================================================================
module vga_timing (
    input  logic       clk50,
    output logic       clk25,      // registered 25 MHz pixel clock -> VGA_CLK
    output logic [9:0] x,
    output logic [9:0] y,
    output logic       active,
    output logic       hsync,
    output logic       vsync
);
    // 640x480@60 standard timing
    localparam int H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    localparam int V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33;
    localparam int H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800
    localparam int V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    // divided, registered pixel clock
    logic pix = 1'b0;
    always_ff @(posedge clk50) pix <= ~pix;
    assign clk25 = pix;

    // pixel counters: advance one position per VGA_CLK period
    logic [9:0] hc = 10'd0, vc = 10'd0;
    always_ff @(posedge clk50) begin
        if (pix) begin
            if (hc == H_TOTAL - 1) begin
                hc <= 10'd0;
                vc <= (vc == V_TOTAL - 1) ? 10'd0 : vc + 10'd1;
            end else begin
                hc <= hc + 10'd1;
            end
        end
    end

    assign x      = hc;
    assign y      = vc;
    assign active = (hc < H_VISIBLE) && (vc < V_VISIBLE);
    assign hsync  = ~((hc >= H_VISIBLE + H_FRONT) &&
                      (hc <  H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync  = ~((vc >= V_VISIBLE + V_FRONT) &&
                      (vc <  V_VISIBLE + V_FRONT + V_SYNC));
endmodule
