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

    //----- deck / shuffle FIFO --------------------------------------------
    logic       take_card, split_en;
    logic [1:0] load_target;
    logic [3:0] next_card;
    logic       shuffle_done, fifo_empty;
    shuffle_fifo u_deck (
        .clk(clk), .rst(rst), .draw_req(take_card),
        .next_card(next_card), .shuffle_done(shuffle_done), .empty(fifo_empty));

    //----- hand registers + totals ----------------------------------------
    logic [MAX_CARDS*4-1:0] cards_a, cards_b, cards_d;
    logic [3:0]             count_a, count_b, count_d;
    logic [7:0]             total_a, total_b, total_d;
    logic                   bust_a, bust_b, bust_d, bj_a, bj_b, bj_d;
    logic                   pair_match;
    hand_registers #(.MAX_CARDS(MAX_CARDS)) u_hands (
        .clk(clk), .rst(rst),
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
        .clk(clk), .rst(rst),
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
        .clk(clk), .rst(rst),
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

    vga_renderer #(.MAX_CARDS(MAX_CARDS)) u_vga (
        .x(px), .y(py), .active(vga_active),
        .cards_a(cards_a), .cards_b(cards_b), .cards_d(cards_d),
        .count_a(count_a), .count_b(count_b), .count_d(count_d),
        .total_a(total_a), .total_b(total_b), .total_d(total_d),
        .reveal_hole(reveal_hole), .split_active(split_active),
        .active_hand(active_hand), .round_over(round_over),
        .result_a(result_a), .result_b(result_b),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B));

    assign VGA_HS      = vga_hs;
    assign VGA_VS      = vga_vs;
    assign VGA_CLK     = ~clk25;        // data set on rising clk25, latched here
    assign VGA_BLANK_N = vga_active;
    assign VGA_SYNC_N  = 1'b0;          // sync-on-green unused
endmodule
