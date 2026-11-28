# Battle Catch

Catches an active wild encounter in Pokémon Brilliant Diamond and Shining Pearl using Sleep,
optional tank heavy-chipping down to 20–30% HP, False Swipe down to 1 HP, and Poké Ball throws,
without ever selecting Run.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- Park the Switch on the wild battle action menu (for example right after `bdsp.static_rng` stops
  on a shiny legendary).
- Ensure your party slots and move slots match the `--options` flags (by default: Slot 1 lead with
  Move 3 Sleep Powder and Move 2 False Swipe, Slot 6 defensive wall, Luxury Balls in the Bag).

## Options

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `target` | groudon \| kyogre \| latios \| latias \| mewtwo \| generic | default `groudon` | Target encounter label for logs and policy defaults. |
| `ball` | luxury \| ultra \| timer \| dusk \| premier \| master | default `luxury` | Poké Ball type to throw. |
| `lead_slot` | 1 to 6 | default `1` | 1-based party slot sent out at battle start. |
| `sleep_slot` | 0 to 6 | default `1` | 1-based party slot of Sleep user (0 disables status). |
| `sleep_move` | 1 to 4 | default `3` | 1-based move slot of the Sleep move. |
| `false_swipe_slot` | 0 to 6 | default `1` | 1-based party slot of False Swipe user (0 disables). |
| `false_swipe_move` | 1 to 4 | default `2` | 1-based move slot of False Swipe. |
| `setup_slot` | 0 to 6 | default `0` | Optional 1-based party slot for stat-boosting setup (0 disables). |
| `setup_move` | 1 to 4 | default `4` | 1-based move slot of the setup move (e.g. Swords Dance). |
| `setup_uses` | 1 to 6 | default `2` | Number of setup turns to execute during the foe's first sleep. |
| `chipper_slot` | 0 to 6 | default `0` | Optional 1-based party slot of tank/bruiser heavy-chipper (0 disables). |
| `chipper_move` | 1 to 4 | default `1` | 1-based move slot of the heavy-chipper's safe neutral attack. |
| `chipper_floor_pct` | 15 to 80 | default `30` | Stop heavy-chipping once foe HP is at or below this percent. |
| `wall_slot` | 0 to 6 | default `6` | Optional 1-based party slot of defensive wall (0 disables). |
| `wall_heal_move` | 0 to 4 | default `0` | Optional 1-based move slot of wall recovery move (0 uses Bag heal). |
| `max_balls` | 1 to 99 | default `60` | Pause after throwing this many balls. |
| `max_turns` | 10 to 200 | default `80` | Pause after this many turns to guard against Struggle. |
| `ball_pocket_steps` | -5 to 5 | default `0` | Horizontal pocket steps from initial battle Bag pocket to Poké Balls. |
| `ball_row` | -20 to 20 | default `-1` | Horizontal steps in the X-button Poké Ball carousel (-1 = Left once for last ball / Luxury Ball). |
| `fallback_ball` | none \| dusk \| timer \| ultra \| luxury \| premier \| master | default `none` | Optional higher-rate Poké Ball switched to at fallback_turn (e.g. dusk or timer) to prevent Struggle KOs. |
| `fallback_turn` | 1 to 200 | default `25` | Turn number at which to switch from ball to fallback_ball. |
| `fallback_ball_steps` | -20 to 20 | default `-6` | Horizontal steps in the X-button Poké Ball carousel from ball to fallback_ball. |
| `heal_pocket_steps` | -5 to 5 | default `0` | Horizontal pocket steps from initial battle Bag pocket to Medicine. |
| `heal_row` | 0 to 20 | default `0` | 0-based row of the healing item in the Medicine pocket. |
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run bdsp.battle_catch --from 01-battle-catch --to 01-battle-catch --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

Example catching Shiny Groudon with Venusaur (slot 1), Garchomp heavy-chipper (slot 5, move 1
down to 30%), Aerodactyl wall (slot 6), and Luxury Balls:

```sh
cd src && opam exec -- dune exec -- gamepilot run bdsp.battle_catch \
  --from 01-battle-catch --to 01-battle-catch --mode testing --watch \
  --backend switch --serial /dev/cu.usbmodem... --capture 0 \
  --options target=groudon --options ball=luxury \
  --options chipper_slot=5 --options chipper_move=1 --options chipper_floor_pct=30 \
  --options wall_slot=6
```

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-battle-catch | Catch the active BDSP wild encounter |

<!-- plans: a8703769cc99 -->
<!-- /generated -->

1. **Sleep first:** Uses the configured `sleep_slot` / `sleep_move` whenever the foe is awake.
2. **Optional heavy chip (down to `chipper_floor_pct`):** Switches to `chipper_slot` and uses
   `chipper_move` while foe HP is above `chipper_floor_pct` (default 30%), stopping well above KO
   range.
3. **False Swipe to 1 HP:** Switches back to `false_swipe_slot` and uses `false_swipe_move` until
   foe HP is in red (≤ 15%).
4. **Ball loop:** Switches to `wall_slot` (when configured) and throws `ball` until caught,
   re-applying Sleep if the foe wakes up and re-chipping if it heals (e.g. Rest / Aqua Ring).

## When it stops

- **Caught:** Battle fades to black after a ball throw and returns to the overworld.
- **Paused:** Stops safely on turn limit, ball limit, unexpected dialog, or timeout — never clicks
  Run.

## How it works

Wires `Bdsp_battle_catch.Battle_catch_options`, `Bdsp_actions.Battle_catch_steps`, and
`Pokemon_catch.Catch_runner` over `Bdsp_readers.Battle_hud`.
