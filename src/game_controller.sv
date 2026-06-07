//==========================================================================
// game_controller.sv  -  the blackjack FSM.
//
// Flow:  IDLE -> SHUF -> BET -> DEAL -> PLAYER_A [-> SPLIT -> PLAYER_A]
//        [-> PLAYER_B] -> DEALER -> RESOLVE -> PAYOUT -> DONE -> IDLE
//
// Card draws use a one-cycle handshake: `take_card` asserts load_en+draw_req
// together, routing the FIFO head (`load_val` in the top) into the hand named
// by `load_target`. Balance changes are single-cycle `bal_strobe` pulses with
// a signed `bal_delta` (debits negative, payouts positive). The FSM reads
// `balance` for double/split legality.
//
// Outputs reveal_hole / split_active / active_hand / round_over / result_*
// feed the VGA renderer and the LED/HEX result display.
//==========================================================================
module game_controller (
    input  logic       clk,
    input  logic       rst,            // new-round pulse

    // player commands (single-cycle)
    input  logic       hit,
    input  logic       stand,
    input  logic       double,
    input  logic       split,

    // status from datapath
    input  logic       shuffle_done,
    input  logic [7:0] total_a,
    input  logic [7:0] total_b,
    input  logic [7:0] total_d,
    input  logic       bust_a,
    input  logic       bust_b,
    input  logic       bust_d,
    input  logic       pair_match,
    input  logic [7:0] balance,

    // deck / hand control
    output logic       take_card,      // load_en + draw_req
    output logic [1:0] load_target,    // 0=A,1=B,2=dealer
    output logic       split_en,

    // balance control
    output logic       bal_strobe,
    output logic signed [7:0] bal_delta,

    // display / status
    output logic       reveal_hole,
    output logic       split_active,
    output logic       active_hand,    // 0 = A, 1 = B
    output logic       round_over,
    output logic [1:0] result_a,
    output logic [1:0] result_b
);
    //----- encodings ------------------------------------------------------
    localparam logic [1:0] HAND_A = 2'd0;
    localparam logic [1:0] HAND_B = 2'd1;
    localparam logic [1:0] HAND_D = 2'd2;

    localparam logic [1:0] R_NONE = 2'd0;
    localparam logic [1:0] R_WIN  = 2'd1;
    localparam logic [1:0] R_LOSE = 2'd2;
    localparam logic [1:0] R_PUSH = 2'd3;

    typedef enum logic [4:0] {
        S_IDLE, S_SHUF, S_BET, S_DEAL,
        S_PA, S_PA_CHK, S_AEND,
        S_SPLIT, S_SPLIT_A, S_SPLIT_B,
        S_DBL_A,
        S_PB, S_PB_CHK, S_BEND, S_DBL_B,
        S_DLR, S_DLR_CHK,
        S_RESOLVE, S_PAYA, S_PAYB, S_DONE
    } state_t;

    state_t state = S_IDLE;

    //----- datapath registers --------------------------------------------
    logic [2:0] deal_cnt = '0;
    logic [1:0] bet_a    = '0;   // dollars wagered on hand A (1 or 2)
    logic [1:0] bet_b    = '0;   // dollars wagered on hand B (0,1,2)
    logic       acted_a  = 1'b0; // hand A has hit -> no double/split
    logic       acted_b  = 1'b0;

    //----- legality -------------------------------------------------------
    logic double_ok, split_ok;
    assign double_ok = (balance >= 8'd1);
    assign split_ok  = (balance >= 8'd1) && pair_match;

    //----- judging --------------------------------------------------------
    function automatic logic [1:0] judge(
        input logic [7:0] pt, input logic pbust,
        input logic [7:0] dt, input logic dbust);
        if (pbust)             judge = R_LOSE;
        else if (dbust)        judge = R_WIN;
        else if (pt > dt)      judge = R_WIN;
        else if (pt < dt)      judge = R_LOSE;
        else                   judge = R_PUSH;
    endfunction

    function automatic logic signed [7:0] payout(
        input logic [1:0] res, input logic [1:0] bet);
        case (res)
            R_WIN:   payout = signed'(8'(2 * bet)); // return bet + equal win
            R_PUSH:  payout = signed'(8'(bet));     // return bet
            default: payout = 8'sd0;                // loss: nothing back
        endcase
    endfunction

    logic all_player_bust;
    assign all_player_bust = bust_a && (!split_active || bust_b);

    //----- Moore-style status outputs ------------------------------------
    assign reveal_hole = (state == S_DLR) || (state == S_DLR_CHK) ||
                         (state == S_RESOLVE) || (state == S_PAYA) ||
                         (state == S_PAYB) || (state == S_DONE);
    assign round_over  = (state == S_DONE);
    assign active_hand = (state == S_PB) || (state == S_PB_CHK) ||
                         (state == S_DBL_B) || (state == S_BEND);

    //----- combinational deck/balance outputs ----------------------------
    always_comb begin
        take_card   = 1'b0;
        load_target = HAND_A;
        split_en    = 1'b0;
        bal_strobe  = 1'b0;
        bal_delta   = 8'sd0;

        unique case (state)
            S_BET: begin
                bal_strobe = 1'b1;
                bal_delta  = -8'sd1;            // base bet on hand A
            end
            S_DEAL: begin
                take_card   = 1'b1;
                // sequence: A, dealer-up, A, dealer-hole
                load_target = (deal_cnt == 3'd1 || deal_cnt == 3'd3)
                              ? HAND_D : HAND_A;
            end
            S_PA: begin
                if (hit) begin
                    take_card = 1'b1; load_target = HAND_A;
                end
            end
            S_DBL_A: begin
                take_card  = 1'b1; load_target = HAND_A;
                bal_strobe = 1'b1; bal_delta = -8'sd1;
            end
            S_SPLIT: begin
                split_en   = 1'b1;
                bal_strobe = 1'b1; bal_delta = -8'sd1; // bet on hand B
            end
            S_SPLIT_A: begin
                take_card = 1'b1; load_target = HAND_A;
            end
            S_SPLIT_B: begin
                take_card = 1'b1; load_target = HAND_B;
            end
            S_PB: begin
                if (hit) begin
                    take_card = 1'b1; load_target = HAND_B;
                end
            end
            S_DBL_B: begin
                take_card  = 1'b1; load_target = HAND_B;
                bal_strobe = 1'b1; bal_delta = -8'sd1;
            end
            S_DLR: begin
                if (!all_player_bust && (total_d < 8'd17)) begin
                    take_card = 1'b1; load_target = HAND_D;
                end
            end
            S_PAYA: begin
                bal_strobe = 1'b1; bal_delta = payout(result_a, bet_a);
            end
            S_PAYB: begin
                bal_strobe = 1'b1; bal_delta = payout(result_b, bet_b);
            end
            default: ;
        endcase
    end

    //----- sequential next-state + datapath ------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= S_SHUF;
            deal_cnt     <= '0;
            bet_a        <= '0;
            bet_b        <= '0;
            acted_a      <= 1'b0;
            acted_b      <= 1'b0;
            split_active <= 1'b0;
            result_a     <= R_NONE;
            result_b     <= R_NONE;
        end else begin
            unique case (state)
                S_IDLE: ; // wait for rst

                S_SHUF: if (shuffle_done) state <= S_BET;

                S_BET: begin
                    bet_a <= 2'd1;
                    deal_cnt <= '0;
                    state <= S_DEAL;
                end

                S_DEAL: begin
                    if (deal_cnt == 3'd3) state <= S_PA;
                    deal_cnt <= deal_cnt + 3'd1;
                end

                S_PA: begin
                    if (hit) begin
                        acted_a <= 1'b1;
                        state   <= S_PA_CHK;
                    end else if (double && double_ok && !acted_a) begin
                        bet_a <= 2'd2;
                        state <= S_DBL_A;
                    end else if (split && split_ok && !acted_a &&
                                 !split_active) begin
                        split_active <= 1'b1;
                        bet_b        <= 2'd1;
                        state        <= S_SPLIT;
                    end else if (stand) begin
                        state <= S_AEND;
                    end
                end

                S_PA_CHK: state <= bust_a ? S_AEND : S_PA;

                S_DBL_A: state <= S_AEND;   // doubled: one card, hand ends

                S_SPLIT:   state <= S_SPLIT_A;
                S_SPLIT_A: state <= S_SPLIT_B;
                S_SPLIT_B: begin
                    acted_a <= 1'b0;        // fresh hand A, double allowed
                    state   <= S_PA;
                end

                S_AEND: state <= split_active ? S_PB : S_DLR;

                S_PB: begin
                    if (hit) begin
                        acted_b <= 1'b1;
                        state   <= S_PB_CHK;
                    end else if (double && double_ok && !acted_b) begin
                        bet_b <= 2'd2;
                        state <= S_DBL_B;
                    end else if (stand) begin
                        state <= S_BEND;
                    end
                end

                S_PB_CHK: state <= bust_b ? S_BEND : S_PB;
                S_DBL_B:  state <= S_BEND;
                S_BEND:   state <= S_DLR;

                S_DLR: begin
                    if (all_player_bust)            state <= S_RESOLVE;
                    else if (total_d >= 8'd17)       state <= S_RESOLVE;
                    else                             state <= S_DLR_CHK;
                end
                S_DLR_CHK: state <= S_DLR;

                S_RESOLVE: begin
                    result_a <= judge(total_a, bust_a, total_d, bust_d);
                    result_b <= split_active
                                ? judge(total_b, bust_b, total_d, bust_d)
                                : R_NONE;
                    state <= S_PAYA;
                end

                S_PAYA: state <= S_PAYB;
                S_PAYB: state <= S_DONE;
                S_DONE: ; // hold results until next rst

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
