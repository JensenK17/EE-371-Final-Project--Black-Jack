# Blackjack on DE1-SoC — Implementation Plan

Derived from `Lab6_Proposal.pdf`. The design is `blackjack_top` decomposed into
seven major blocks plus a handful of reusable leaf modules. Everything is clocked
by `CLOCK_50`; reset is synchronous and derived from `SW[9]`.

All RTL is **SystemVerilog** (`.sv`). Each module is independently simulated in
ModelSim before integration. Uncomment its `set_global_assignment` line in
`Blackjack.qsf` as each file lands.

---

## 1. Architecture overview

```
                 ┌───────────────────┐
   KEY/SW ──────▶│ input_conditioning│── hit/stand/double/split, rst
                 └─────────┬─────────┘
                           ▼
   ┌──────────────┐   ┌──────────────────┐   ┌──────────────────────┐
   │ deck_memory  │◀──│  game_controller │──▶│ hand_registers       │
   │ shuffle_fifo │──▶│      (FSM)       │   │ + hand_total (x3)    │
   └──────────────┘   └───┬──────────┬───┘   └──────────┬───────────┘
       next_card          │          │                  │ hands, totals
                          ▼          ▼                  ▼
                 ┌──────────────┐  ┌──────────────────────────────┐
                 │balance_tracker│  │ vga_renderer                 │
                 │ + hex_decoder │  │ (vga_timing + char_rom)      │
                 └──────┬────────┘  └──────────────┬───────────────┘
                        ▼                          ▼
                   HEX5..HEX0, LEDR            VGA_R/G/B, HS, VS, ...
```

---

## 2. Module specifications

### 2.1 Leaf / reusable

| Module | Purpose | Key ports |
|--------|---------|-----------|
| `synchronizer.sv` | 2-FF synchronizer for async KEY/SW | `clk, async_in → sync_out` |
| `debouncer.sv` | Debounce + single-cycle rising-edge pulse | `clk, noisy → pulse` |
| `hex_decoder.sv` | 4-bit value → active-low 7-seg | `value[3:0] → seg[6:0]` |

### 2.2 `input_conditioning.sv`
Synchronizes and debounces `KEY[3:0]` and `SW[9]`. Emits single-cycle pulses
`hit, stand, double, split` and a synchronous `rst`. KEYs are **active-low** —
invert on the way in. No legality logic here; the FSM masks double/split.
- In: `clk, KEY[3:0], sw9`
- Out: `hit, stand, double, split, rst`

### 2.3 `deck_memory.sv`
52×4-bit ROM holding card values 1–13, four copies each. Read-only.
- In: `addr[5:0]` → Out: `card_val[3:0]`
- Init via an inline `$readmemh`/`initial` table or a `.mif`.

### 2.4 `shuffle_fifo.sv` (LFSR shuffle + deck FIFO)
On `rst`, a maximal-length LFSR generates addresses into `deck_memory`;
Fisher–Yates-style fill with a 52-bit `used` mask rejects duplicates until all 52
unique cards are enqueued. During play, `draw_req` pops the front.
- In: `clk, rst, draw_req`
- Out: `next_card[3:0], card_ready, empty, shuffle_done`
- Internal: `lfsr` (seeded non-zero), `used[51:0]`, FIFO storage + r/w pointers.

### 2.5 `hand_total.sv` (combinational)
Sum a hand with the Ace rule: total all aces as 11, then subtract 10 per ace
while total > 21.
- In: `card_vals` (packed array, up to ~10 cards), `count[3:0]`
- Out: `total[5:0], is_bust, is_blackjack`

### 2.6 `hand_registers.sv`
Three hands: player A, player B (split only), dealer — each up to ~10 cards plus
a count. Appends a card to the hand selected by `target_hand` on `load_card`.
Instantiates three `hand_total`. Exposes `pair_match` = (player A card0 == card1).
- In: `clk, rst, load_card, target_hand[1:0], card_val[3:0], split_init`
- Out: hand arrays + counts, `total_a/b/dealer`, `is_bust_*`, `pair_match`

### 2.7 `game_controller.sv` (FSM) — core of the design
States: `IDLE → DEAL → PLAYER_TURN_A → PLAYER_TURN_B → DEALER_TURN → RESOLVE →
PAYOUT → IDLE`.
- **DEAL**: player, dealer-up, player, dealer-hole (face down). Debit base $1.
- After deal: compute legality — `double_ok = balance≥1`, `split_ok = balance≥1
  & pair_match`.
- **PLAYER_TURN_A/B**: Hit pops a card to the active hand; Stand advances;
  Double debits $1, deals one card, ends hand; Split (A only) deals one card to
  each hand, sets per-hand 2×-bet/doubled flags. `PLAYER_TURN_B` bypassed when no
  split. Per-hand `first_action` flag gates double/split (cleared on first hit).
- **DEALER_TURN**: reveal hole, auto-draw until total ≥ 17.
- **RESOLVE**: compare each player hand vs dealer; set `result_a/result_b`
  (win/lose/push), each with its bet multiplier.
- **PAYOUT**: emit `bet_delta` settlements to balance_tracker; back to IDLE.
- Drives: `deal_card, target_hand, draw_req, active_hand, reveal_hole,
  result_a, result_b, bet_mult_a, bet_mult_b, bet_delta/settle pulses`.

### 2.8 `vga_timing.sv`
640×480@60 timing (25.175 MHz pixel clock from a PLL, or /2 of 50 MHz as a first
cut). Outputs `hsync, vsync, blank_n, sync_n, x[9:0], y[9:0], active`.

### 2.9 `char_rom.sv`
Small bitmap font (8×8 or 8×16) for digits and the short strings DEALER, PLAYER,
TOTAL, WIN/LOSE/PUSH, DBL.

### 2.10 `vga_renderer.sv`
Split-screen: dealer top, player bottom, dashed divider. Draws each card as a
white box with the value centered (box drawer + `char_rom`). Hole card = patterned
back until `reveal_hole`. On `split_active`, hand A lower-left, hand B lower-right,
active hand gets a yellow border + triangle cursor. Status banner + balance bar.
Start with a low-color (3-bit RGB) on-the-fly rasterizer; add a 320×240 frame
buffer in on-chip RAM only if needed for bandwidth.
- In: hand arrays + totals, `reveal_hole, split_active, active_hand, result_*,
  balance, status_code`, pixel `x/y`
- Out: `VGA_R/G/B`

### 2.11 `balance_tracker.sv`
Holds balance (start $5; reset to $5 only if it hit $0). Applies `bet_delta` per
settled hand with its 1×/2× multiplier. Win pays 2× bet, push returns bet, loss
forfeits. Drives six `hex_decoder` instances and the LEDR result indicators.
- In: `clk, rst, settle pulses, result_a/b, bet_mult_a/b`
- Out: `balance, HEX5..HEX0, LEDR`

---

## 3. Build order & milestones

Bottom-up so every block is testable against a bench before integration.

- **M0 — Project skeleton.** ✅ `.qpf/.qsf`, top compiles, pins assigned.
- **M1 — Input + HEX path.** ✅ `synchronizer`, `debouncer`,
  `input_conditioning`, `hex_decoder`, `balance_tracker`.
- **M2 — Deck.** ✅ `deck_memory`, `lfsr`, `shuffle_fifo`. Coverage checked by
  `tb_shuffle_fifo` (52 unique, 4× each rank).
- **M3 — Hand math.** ✅ `hand_total` (ace edge cases in `tb_hand_total`),
  `hand_registers` with `pair_match`.
- **M4 — FSM core.** ✅ `game_controller`. Directed scenarios in `tb_game`.
- **M5 — Double & split.** ✅ DOUBLE, SPLIT, PLAYER_TURN_B, per-hand bets,
  `first_action` (acted_*) gating. Covered by `tb_game`.
- **M6 — VGA.** ✅ `vga_timing`, `char_rom`, `vga_renderer` (cards, rank
  glyphs, hole-card back/reveal, split layout w/ active+dim, totals, banner,
  balance bar). Verify on the monitor.
- **M7 — Integration & polish.** ✅ wired in `blackjack_top`. Remaining:
  on-board play-through + Quartus timing closure (do on the lab machine).

**Status: all modules built and wired.** Logic is verified in ModelSim
(`tb_hand_total`, `tb_shuffle_fifo`, `tb_game`). VGA must be confirmed on the
physical monitor; Quartus compile + timing closure happen on the board machine.

## Known simplifications / TODO

- **No blackjack 3:2 bonus.** Naturals are scored as a plain 21 (compare
  totals), matching the proposal's resolve rules.
- **Banner shows color only** (green/red/yellow), no word text yet; result is
  also on LEDR. Card ranks and hand totals *are* rendered via the font.
- **VGA reads game state across clock domains** (25 MHz pixel vs 50 MHz logic)
  without resync. State changes are brief and rare, so tearing is unlikely; add
  a resync stage if artifacts appear.
- **Pixel clock is a /2 divider**, not a PLL. Swap to a PLL if the monitor
  won't lock.
- **Up to 5 cards/hand drawn** on screen (more are still scored correctly).

---

## 4. Verification plan (ModelSim, one bench per module)

| Bench | Focus |
|-------|-------|
| `tb_shuffle_fifo` | 52 unique cards, full coverage, many LFSR seeds, no repeats |
| `tb_hand_total` | Exhaustive ≤5-card hands incl. multi-ace (A-A, A-A-9, …) |
| `tb_game_controller` | player/dealer bust, push, blackjack, double ±, double<$1 reject, split both-win, split one-bust, split non-pair reject |
| `tb_balance_tracker` | win/push/loss payouts, 2× doubled, $0→$5 reset, per-hand split settle |
| `tb_input_conditioning` | debounce, single-cycle pulse, active-low KEY |
| VGA | Dump pixel stream in sim, then confirm on the DE1-SoC monitor |

---

## 5. Decisions to confirm / open questions

1. **Pixel clock**: PLL for 25.175 MHz vs. a 25 MHz divide of CLOCK_50. Start
   with the divider; add a PLL if the monitor won't sync.
2. **Renderer**: on-the-fly rasterization first; frame buffer only if BRAM allows
   and bandwidth demands. (Proposal's fallback plan.)
3. **HEX balance format**: decimal dollars across HEX1/HEX0 (and a `$` glyph on
   HEX5?) vs. raw value. Lean decimal.
4. **Naming**: `.sv` SystemVerilog throughout (matches CSE 371 toolflow).

---

## 6. Stretch goals (only if time permits)

Variable bet on switches • re-splitting • insurance when dealer up-card is Ace •
suit icons • win/loss audio cue.
