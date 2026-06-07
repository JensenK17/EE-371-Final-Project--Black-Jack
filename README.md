# Blackjack: Player vs. House — DE1-SoC

CSE 371 Lab 6 final project. A one-player Blackjack (21) game on the DE1-SoC,
with the FPGA acting as the dealer. Cards render on a VGA monitor; balance shows
on the HEX displays; KEYs drive Hit / Stand / Double / Split; SW9 shuffles and
starts a new round.

## Board I/O

| Signal   | DE1-SoC I/O   | Purpose                                            |
|----------|---------------|----------------------------------------------------|
| HIT      | KEY[3]        | Request another card                               |
| STAND    | KEY[0]        | End current hand                                    |
| DOUBLE   | KEY[2]        | Double bet, take one card, end hand (needs ≥ $1)   |
| SPLIT    | KEY[1]        | Split a starting pair (needs pair + ≥ $1)          |
| RESET    | SW[9]         | Shuffle deck, clear hands, start new round         |
| Display  | VGA 640×480   | Cards, totals, divider, banner, cursor             |
| Balance  | HEX5..HEX0    | Player balance in dollars                          |
| Result   | LEDR          | Win / loss / push (per hand on split)              |

## Build (Quartus Prime 18.1, on a lab/board machine)

```
quartus_sh --flow compile Blackjack
```

Or open `Blackjack.qpf` in the Quartus GUI and compile. Device: Cyclone V
**5CSEMA5F31C6** (DE1-SoC).

## Simulate (ModelSim / Questa)

From the project root:

```
vsim -c -do sim/run.do                                   # runs tb_game
vsim -c -do "set TB tb_shuffle_fifo; do sim/run.do"      # deck coverage
vsim -c -do "set TB tb_hand_total;   do sim/run.do"      # ace/total rules
vsim -do "set GUI 1; do sim/run.do"                      # GUI + waves
```

Each testbench prints `ALL PASS` or a `FAILURES` count. `tb_game` exercises
stand-win, player bust, double-down, split (both win), and split-rejected-on-
non-pair by checking the running balance.

## Layout

```
Blackjack.qpf / .qsf     Quartus project + DE1-SoC pin assignments
blackjack_top.sv         Top-level (board I/O); instantiates the blocks below
src/                     RTL leaf + block modules
tb/                      ModelSim testbenches (one per module)
docs/IMPLEMENTATION_PLAN.md   Build order, module specs, milestones
```

See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for the full plan.
