//==========================================================================
// blackjack_top.sv
// Blackjack: Player vs. House on the DE1-SoC. Top-level integration of the
// seven blocks.
//
//   KEY[3] = HIT     KEY[2] = DOUBLE   KEY[1] = SPLIT   KEY[0] = STAND
//   SW[9]  = RESET (shuffle + new round)
//   HEX5..HEX0 = balance        LEDR = round result        VGA = table
//==========================================================================
module blackjack_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,        // active-low pushbuttons
    input  logic [9:0]  SW,

    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5,

    output logic [7:0]  VGA_R,
    output logic [7:0]  VGA_G,
    output logic [7:0]  VGA_B,
    output logic        VGA_CLK,
    output logic        VGA_BLANK_N,
    output logic        VGA_SYNC_N,
    output logic        VGA_HS,
    output logic        VGA_VS
);
    localparam int MAX_CARDS = 11;

    logic clk;
    assign clk = CLOCK_50;

    //----- input conditioning ---------------------------------------------
    logic hit, stand, double, split, rst;
    input_conditioning #(.DEB(500_000)) u_in (
        .clk(clk), .KEY(KEY), .sw9(SW[9]),
        .hit(hit), .stand(stand), .double(double), .split(split), .rst(rst));

    // The first hand is started by the player's first SW9 press (not auto-
    // dealt): an FPGA has no entropy at a fixed moment after power-up, so an
    // auto-dealt hand would be identical every time. Sampling the free-running
    // shuffle LFSR at the unpredictable moment of a button press is what makes
    // the deck -- including the first, charged hand -- actually random.
    logic sys_rst;
    assign sys_rst = rst;

    //----- deck / shuffle FIFO --------------------------------------------
    logic       take_card, split_en;
    logic [1:0] load_target;
    logic [3:0] next_card;
    logic       shuffle_done, fifo_empty;
    shuffle_fifo u_deck (
        .clk(clk), .rst(sys_rst), .draw_req(take_card),
        .next_card(next_card), .shuffle_done(shuffle_done), .empty(fifo_empty));

    //----- hand registers + totals ----------------------------------------
    logic [MAX_CARDS*4-1:0] cards_a, cards_b, cards_d;
    logic [3:0]             count_a, count_b, count_d;
    logic [7:0]             total_a, total_b, total_d;
    logic                   bust_a, bust_b, bust_d, bj_a, bj_b, bj_d;
    logic                   pair_match;
    hand_registers #(.MAX_CARDS(MAX_CARDS)) u_hands (
        .clk(clk), .rst(sys_rst),
        .load_en(take_card), .load_target(load_target), .load_val(next_card),
        .split_en(split_en),
        .cards_a(cards_a), .cards_b(cards_b), .cards_d(cards_d),
        .count_a(count_a), .count_b(count_b), .count_d(count_d),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .bust_a(bust_a), .bust_b(bust_b), .bust_d(bust_d),
        .bj_a(bj_a), .bj_b(bj_b), .bj_d(bj_d),
        .pair_match(pair_match));

    //----- balance --------------------------------------------------------
    logic              bal_strobe;
    logic signed [7:0] bal_delta;
    logic [7:0]        balance;

    //----- game controller (FSM) ------------------------------------------
    logic       reveal_hole, split_active, active_hand, round_over;
    logic [1:0] result_a, result_b;
    game_controller u_fsm (
        .clk(clk), .rst(sys_rst),
        .hit(hit), .stand(stand), .double(double), .split(split),
        .shuffle_done(shuffle_done),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .bust_a(bust_a), .bust_b(bust_b), .bust_d(bust_d),
        .pair_match(pair_match), .balance(balance),
        .take_card(take_card), .load_target(load_target), .split_en(split_en),
        .bal_strobe(bal_strobe), .bal_delta(bal_delta),
        .reveal_hole(reveal_hole), .split_active(split_active),
        .active_hand(active_hand), .round_over(round_over),
        .result_a(result_a), .result_b(result_b));

    balance_tracker u_bal (
        .clk(clk), .rst(sys_rst),
        .bal_strobe(bal_strobe), .bal_delta(bal_delta),
        .round_over(round_over), .result_a(result_a), .result_b(result_b),
        .balance(balance),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .LEDR(LEDR));

    //----- VGA ------------------------------------------------------------
    logic       clk25, vga_active, vga_hs, vga_vs;
    logic [9:0] px, py;
    vga_timing u_vt (
        .clk50(clk), .clk25(clk25), .x(px), .y(py),
        .active(vga_active), .hsync(vga_hs), .vsync(vga_vs));

    // LabsLand presents the frame horizontally mirrored, so pre-flip the X
    // coordinate used for drawing. Registered so the subtractor stays out of
    // the renderer's (already deep) combinational path; sync/blanking use the
    // true scan position.
    logic [9:0] rx, ry;
    always_ff @(posedge clk) begin
        if (clk25) begin
            rx <= 10'd639 - px;
            ry <= py;
        end
    end

    // combinational color from the renderer
    logic [7:0] r_c, g_c, b_c;
    vga_renderer #(.MAX_CARDS(MAX_CARDS)) u_vga (
        .x(rx), .y(ry), .active(vga_active),
        .cards_a(cards_a), .cards_b(cards_b), .cards_d(cards_d),
        .count_a(count_a), .count_b(count_b), .count_d(count_d),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .reveal_hole(reveal_hole), .split_active(split_active),
        .active_hand(active_hand), .round_over(round_over),
        .result_a(result_a), .result_b(result_b),
        .VGA_R(r_c), .VGA_G(g_c), .VGA_B(b_c));

    // Register the pixel + sync one pixel-clock period (enable = clk25 high).
    // This gives the (combinational) renderer a full pixel period to settle
    // and presents the ADV7123 a clean, glitch-free registered signal.
    logic [7:0] vr, vg, vb;
    logic       vhs, vvs, vbl;
    always_ff @(posedge clk) begin
        if (clk25) begin
            vr  <= r_c;  vg <= g_c;  vb <= b_c;
            vhs <= vga_hs; vvs <= vga_vs; vbl <= vga_active;
        end
    end

    assign VGA_R       = vr;
    assign VGA_G       = vg;
    assign VGA_B       = vb;
    assign VGA_HS      = vhs;
    assign VGA_VS      = vvs;
    assign VGA_BLANK_N = vbl;
    assign VGA_CLK     = clk25;         // registered pixel clock; DAC latches on its rising edge
    assign VGA_SYNC_N  = 1'b0;          // sync-on-green unused
endmodule
