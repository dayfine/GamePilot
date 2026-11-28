# FRLG Capture Ball Budget

When a FireRed/LeafGreen capture plan (`capture` or `wild_rng`) omits `"balls"` and the user does
not pass `--options balls=N`, pre-flight computes the required ball count from the Generation III
catch-rate formula (`Frlg_actions.Catch_ball_budget`) instead of using a flat default.

Explicit `"balls"` in a plan JSON or `--options balls=N` on the command line always overrides the
computed budget. Unknown species slugs and `uncaught` targets fall back to the plan's default (`5`).

## Gen 3 catch probability formula

From `pokefirered` (`src/battle_script_commands.c`, `Cmd_handleballthrow`):

1. **Modified catch rate**:
   $$a = \text{HP factor} \times \text{CatchRate} \times \text{BallBonus} \times \text{StatusBonus}$$
   If $a \ge 255$, the catch is guaranteed ($p = 1$).
2. **Shake threshold** (for $a < 255$, flooring $a$ to at least $1$):
   $$b = \left\lfloor \frac{1048560}{\sqrt{\sqrt{16711680 / a}}} \right\rfloor$$
3. **Single-ball catch probability** (four independent 16-bit shake checks):
   $$p = \left(\frac{b}{65536}\right)^4$$
4. **99% cumulative ball budget** ($1 - (1 - p)^n \ge 0.99$):
   $$n = \left\lceil \frac{\ln(0.01)}{\ln(1 - p)} \right\rceil$$
   Clamped to `[5, 99]` for standard balls. A **Master Ball** always requires `1`.

## Ball multipliers

| Ball | Slug | Multiplier |
|---|---|---|
| Poké Ball | `poke-ball` | 1.0x |
| Luxury Ball | `luxury-ball` | 1.0x |
| Great Ball | `great-ball` | 1.5x |
| Ultra Ball | `ultra-ball` | 2.0x |
| Master Ball | `master-ball` | Guaranteed (1 ball) |

## Catch-mode HP and status assumptions

| Plan `catch_mode` | Assumption | HP factor | Status bonus |
|---|---|---|---|
| `throw_only` (default, and `capture`) | Full HP, no status | `1/3` | `1.0x` |
| `phase1` / `phase2` | False Swipe to 1 HP + Sleep (Spore) | `1.0` | `2.0x` |

## Example budgets (99% cumulative catch probability)

### Throw-only (full HP, no status)

| Tier | Example species | Poké / Luxury (1x) | Great (1.5x) | Ultra (2x) | Master |
|---|---|---:|---:|---:|---:|
| CR 255 | Oddish, Ekans, Pidgey, Rattata | 12 | 7 | 5 | 1 |
| CR 190 | Growlithe, Psyduck, Voltorb, Shellder | 17 | 10 | 7 | 1 |
| CR 45 | Electabuzz, Scyther, Dratini | 76 | 52 | 37 | 1 |
| CR 3 | Zapdos, Articuno, Moltres, Mewtwo | 99 | 99 | 99 | 1 |

### Weakened + asleep (`phase1` / `phase2`: 1 HP + Sleep)

| Tier | Example species | Poké / Luxury (1x) | Great (1.5x) | Ultra (2x) | Master |
|---|---|---:|---:|---:|---:|
| CR 255 | Oddish, Ekans, Pidgey, Rattata | 5 | 5 | 5 | 1 |
| CR 190 | Growlithe, Psyduck, Voltorb, Shellder | 5 | 5 | 5 | 1 |
| CR 45 | Electabuzz, Scyther, Dratini | 11 | 7 | 5 | 1 |
| CR 3 | Zapdos, Articuno, Moltres, Mewtwo | 99 | 99 | 96 | 1 |
