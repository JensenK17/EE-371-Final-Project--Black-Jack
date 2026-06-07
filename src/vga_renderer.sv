//==========================================================================
// vga_renderer.sv  -  combinational table renderer for the blackjack game.
//
// Layout (640x480): dealer hand + total on top, player hand(s) + total on the
// bottom, separated by a dashed divider with a status banner. Cards are white
// boxes with the rank drawn from char_rom; the dealer's 2nd card is a red back
// with a '?' until reveal_hole. On a split, the player area shows two hands -
// the active one keeps a white face + yellow border, the inactive one is
// dimmed. The banner turns green/red/yellow on win/lose/push.
//
// Pixel color is produced purely from (x, y) and the current game state.
//==========================================================================
module vga_renderer #(
    parameter int MAX_CARDS = 11
) (
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic       active,

    input  logic [MAX_CARDS*4-1:0] cards_a,
    input  logic [MAX_CARDS*4-1:0] cards_b,
    input  logic [MAX_CARDS*4-1:0] cards_d,
    input  logic [3:0]             count_a,
    input  logic [3:0]             count_b,
    input  logic [3:0]             count_d,
    input  logic [7:0]             total_a,
    input  logic [7:0]             total_b,
    input  logic [7:0]             total_d,

    input  logic       reveal_hole,
    input  logic       split_active,
    input  logic       active_hand,   // 0 = A, 1 = B
    input  logic       round_over,
    input  logic [1:0] result_a,
    input  logic [1:0] result_b,

    output logic [7:0] VGA_R,
    output logic [7:0] VGA_G,
    output logic [7:0] VGA_B
);
    localparam logic [1:0] R_WIN  = 2'd1;
    localparam logic [1:0] R_LOSE = 2'd2;
    localparam logic [1:0] R_PUSH = 2'd3;

    // ---- card geometry ----
    localparam int CW = 46, CH = 66, PITCH = 52;
    localparam int OXD = 170, OYD = 48;      // dealer row
    localparam int OXP = 170, OYP = 300;     // player (no split)
    localparam int OXA = 36,  OXB = 350, OYS = 300; // split hands

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
    function automatic logic [3:0] nib(input logic [MAX_CARDS*4-1:0] f,
                                       input logic [2:0] idx);
        case (idx)
            3'd0: nib = f[3:0];
            3'd1: nib = f[7:4];
            3'd2: nib = f[11:8];
            3'd3: nib = f[15:12];
            default: nib = f[19:16];
        endcase
    endfunction

    // locate a pixel within a 5-card hand row -> {hit, slot[2:0], lx[6:0], ly[6:0]}
    function automatic logic [17:0] locate(input logic [9:0] px, input logic [9:0] py,
                                           input int ox, input int oy, input logic [3:0] cnt);
        logic        hit;  logic [2:0] slot;  logic [6:0] lx, ly;
        int relx, rely, s, inx;
        hit = 1'b0; slot = '0; lx = '0; ly = '0;
        relx = int'(px) - ox;
        rely = int'(py) - oy;
        if (rely >= 0 && rely < CH && relx >= 0) begin
            s   = relx / PITCH;
            inx = relx - s * PITCH;
            if (s < 5 && s < int'(cnt) && inx < CW) begin
                hit = 1'b1; slot = 3'(s); lx = 7'(inx); ly = 7'(rely);
            end
        end
        return {hit, slot, lx, ly};
    endfunction

    // rank -> {n, code0, code1}: n=0 single glyph, n=1 two glyphs ("10")
    function automatic logic [8:0] rankchars(input logic [3:0] v);
        logic n; logic [3:0] c0, c1;
        n = 1'b0; c0 = 4'd15; c1 = 4'd15;
        if      (v == 4'd1)  c0 = 4'd10;            // A
        else if (v <= 4'd9)  c0 = v;               // 2..9
        else if (v == 4'd10) begin n = 1'b1; c0 = 4'd1; c1 = 4'd0; end
        else if (v == 4'd11) c0 = 4'd11;           // J
        else if (v == 4'd12) c0 = 4'd12;           // Q
        else                 c0 = 4'd13;           // K
        return {n, c0, c1};
    endfunction

    // ----------------------------------------------------------------
    // Which hand/card is this pixel in?
    // ----------------------------------------------------------------
    logic        in_card, holeback, dim, activeborder;
    logic [2:0]  slot;
    logic [6:0]  lx, ly;
    logic [3:0]  card_val;

    logic [17:0] loc_d, loc_p, loc_a, loc_b;
    assign loc_d = locate(x, y, OXD, OYD, count_d);
    assign loc_p = locate(x, y, OXP, OYP, count_a);
    assign loc_a = locate(x, y, OXA, OYS, count_a);
    assign loc_b = locate(x, y, OXB, OYS, count_b);

    always_comb begin
        in_card = 1'b0; holeback = 1'b0; dim = 1'b0; activeborder = 1'b0;
        slot = '0; lx = '0; ly = '0; card_val = 4'd15;

        if (loc_d[17]) begin                       // dealer
            in_card  = 1'b1;
            slot     = loc_d[16:14]; lx = loc_d[13:7]; ly = loc_d[6:0];
            card_val = nib(cards_d, slot);
            holeback = (slot == 3'd1) && !reveal_hole;
        end else if (!split_active && loc_p[17]) begin // single player
            in_card  = 1'b1;
            slot     = loc_p[16:14]; lx = loc_p[13:7]; ly = loc_p[6:0];
            card_val = nib(cards_a, slot);
        end else if (split_active && loc_a[17]) begin  // split hand A
            in_card  = 1'b1;
            slot     = loc_a[16:14]; lx = loc_a[13:7]; ly = loc_a[6:0];
            card_val = nib(cards_a, slot);
            activeborder = (active_hand == 1'b0);
            dim          = (active_hand != 1'b0);
        end else if (split_active && loc_b[17]) begin  // split hand B
            in_card  = 1'b1;
            slot     = loc_b[16:14]; lx = loc_b[13:7]; ly = loc_b[6:0];
            card_val = nib(cards_b, slot);
            activeborder = (active_hand == 1'b1);
            dim          = (active_hand != 1'b1);
        end
    end

    // ----------------------------------------------------------------
    // Card glyph lookup
    // ----------------------------------------------------------------
    logic        rc_n;
    logic [3:0]  rc_c0, rc_c1;
    always_comb begin
        logic [8:0] rc;
        if (holeback) begin
            rc_n = 1'b0; rc_c0 = 4'd14; rc_c1 = 4'd15; // '?'
        end else begin
            rc    = rankchars(card_val);
            rc_n  = rc[8]; rc_c0 = rc[7:4]; rc_c1 = rc[3:0];
        end
    end

    logic        cg_region;
    logic [3:0]  cg_code;
    logic [2:0]  cg_row, cg_col;
    always_comb begin
        int gx, gyl;
        cg_region = 1'b0; cg_code = 4'd15; cg_row = '0; cg_col = '0;
        if (ly >= 7'd25 && ly < 7'd41) begin
            gyl = int'(ly) - 25;
            if (!rc_n) begin
                if (lx >= 7'd15 && lx < 7'd31) begin
                    cg_region = 1'b1; gx = int'(lx) - 15; cg_code = rc_c0;
                    cg_col = 3'((gx) >> 1);
                end
            end else begin
                if (lx >= 7'd7 && lx < 7'd23) begin
                    cg_region = 1'b1; gx = int'(lx) - 7;  cg_code = rc_c0;
                    cg_col = 3'((gx) >> 1);
                end else if (lx >= 7'd23 && lx < 7'd39) begin
                    cg_region = 1'b1; gx = int'(lx) - 23; cg_code = rc_c1;
                    cg_col = 3'((gx) >> 1);
                end
            end
            cg_row = 3'(gyl >> 1);
        end
    end

    logic [7:0] cg_bits;
    char_rom u_card (.code(cg_code), .row(cg_row), .bits(cg_bits));
    logic card_glyph_on;
    assign card_glyph_on = cg_region & cg_bits[7 - cg_col];

    // ----------------------------------------------------------------
    // Totals (white digits): dealer + player(s)
    // ----------------------------------------------------------------
    // Choose the total field this pixel falls in.
    logic        tf_hit;       // pixel inside some total field
    logic [3:0]  tf_digit;     // digit value to show (15 = blank)
    logic [2:0]  tf_row, tf_col;

    function automatic logic [7:0] field(input logic [9:0] px, input logic [9:0] py,
                                          input int px0, input int py0,
                                          input logic en, input logic [7:0] val);
        // returns {hit, digit[3:0], col[2:0]} packed as 8 bits; row taken globally
        logic hit; logic [3:0] digit; logic [2:0] col;
        int rx, ry, gx; logic [3:0] tens, ones;
        hit = 1'b0; digit = 4'd15; col = '0;
        tens = 4'((val / 8'd10) % 8'd10);
        ones = 4'(val % 8'd10);
        rx = int'(px) - px0;
        ry = int'(py) - py0;
        if (en && ry >= 0 && ry < 16 && rx >= 0 && rx < 32) begin
            hit = 1'b1;
            if (rx < 16) begin
                gx    = rx;
                digit = (tens == 4'd0) ? 4'd15 : tens;
            end else begin
                gx    = rx - 16;
                digit = ones;
            end
            col = 3'(gx >> 1);
        end
        return {hit, digit, col};
    endfunction

    logic [7:0] fd, fp, fa, fb;
    assign fd = field(x, y, 540, 70,  reveal_hole,            total_d);
    assign fp = field(x, y, 540, 406, ~split_active,          total_a);
    assign fa = field(x, y, 120, 406, split_active,           total_a);
    assign fb = field(x, y, 470, 406, split_active,           total_b);

    always_comb begin
        int ry;
        tf_hit = 1'b0; tf_digit = 4'd15; tf_col = '0; tf_row = '0;
        if      (fd[7]) begin tf_hit = 1'b1; tf_digit = fd[6:3]; tf_col = fd[2:0]; ry = int'(y) - 70;  end
        else if (fp[7]) begin tf_hit = 1'b1; tf_digit = fp[6:3]; tf_col = fp[2:0]; ry = int'(y) - 406; end
        else if (fa[7]) begin tf_hit = 1'b1; tf_digit = fa[6:3]; tf_col = fa[2:0]; ry = int'(y) - 406; end
        else if (fb[7]) begin tf_hit = 1'b1; tf_digit = fb[6:3]; tf_col = fb[2:0]; ry = int'(y) - 406; end
        else ry = 0;
        tf_row = 3'(ry >> 1);
    end

    logic [7:0] tot_bits;
    char_rom u_total (.code(tf_digit), .row(tf_row), .bits(tot_bits));
    logic total_glyph_on;
    assign total_glyph_on = tf_hit & tot_bits[7 - tf_col];

    // ----------------------------------------------------------------
    // Backgrounds: divider, banner, balance bar
    // ----------------------------------------------------------------
    logic in_banner, in_divider, in_balancebar;
    assign in_banner    = (y >= 10'd212) && (y < 10'd268) &&
                          (x >= 10'd200) && (x < 10'd440);
    assign in_divider   = (y >= 10'd236) && (y < 10'd240) && (x[4]); // dashes
    assign in_balancebar= (y >= 10'd456);

    function automatic logic [23:0] result_color(input logic [1:0] r);
        case (r)
            R_WIN:   result_color = {8'h00, 8'hA0, 8'h00};
            R_LOSE:  result_color = {8'hC8, 8'h00, 8'h00};
            R_PUSH:  result_color = {8'hC8, 8'hC8, 8'h00};
            default: result_color = {8'h10, 8'h10, 8'h10};
        endcase
    endfunction

    // ----------------------------------------------------------------
    // Compose final color (priority high -> low)
    // ----------------------------------------------------------------
    logic [7:0] r8, g8, b8;
    always_comb begin
        logic border;
        logic [23:0] bclr;
        // default: table green
        r8 = 8'h00; g8 = 8'h64; b8 = 8'h00;

        if (in_card) begin
            border = (lx < 7'd3) || (lx >= 7'(CW-3)) ||
                     (ly < 7'd3) || (ly >= 7'(CH-3));
            if (border) begin
                if (activeborder) begin r8=8'hE6; g8=8'hE6; b8=8'h00; end // yellow
                else              begin r8=8'h00; g8=8'h00; b8=8'h00; end // black
            end else if (holeback) begin
                if (card_glyph_on) begin r8=8'hF0; g8=8'hD0; b8=8'h00; end // '?'
                else               begin r8=8'hC0; g8=8'h00; b8=8'h00; end // red back
            end else begin
                if (card_glyph_on) begin r8=8'h00; g8=8'h00; b8=8'h00; end // rank
                else if (dim)      begin r8=8'h5A; g8=8'h78; b8=8'h5A; end // dim face
                else               begin r8=8'hFF; g8=8'hFF; b8=8'hFF; end // white face
            end
        end else if (in_banner) begin
            if (round_over) begin
                bclr = split_active
                       ? ((x < 10'd320) ? result_color(result_a) : result_color(result_b))
                       : result_color(result_a);
            end else begin
                bclr = {8'h10, 8'h10, 8'h10};
            end
            r8 = bclr[23:16]; g8 = bclr[15:8]; b8 = bclr[7:0];
        end else if (in_balancebar) begin
            r8 = 8'h08; g8 = 8'h20; b8 = 8'h08;
        end else if (total_glyph_on) begin
            r8 = 8'hFF; g8 = 8'hFF; b8 = 8'hFF;
        end else if (in_divider) begin
            r8 = 8'hC0; g8 = 8'hC0; b8 = 8'hC0;
        end
    end

    assign VGA_R = active ? r8 : 8'h00;
    assign VGA_G = active ? g8 : 8'h00;
    assign VGA_B = active ? b8 : 8'h00;
endmodule
