# Screen graph: `go_to` a screen by reading, not by script (2026-11-26)

A game's menu screens as a graph the game declares, and one game-agnostic `go_to` that reads where
the game is, takes one press toward the target, and reads again. The user took every recommendation
(2026-11-26); the questions it settled are at the end.

## The problem

The user's framing: "It's sort of a very general problem and I wonder if we could have a very
general solution, e.g. when checking all party members, you don't want to close out the menu all
the way each time and then redo it 6 times."

Today every action is written "from the home screen, back to the home screen", with its own entry
and exit presses:

- **PLZA claim-gifts.** `Gift_claim.claim` is "from the main menu back to the main menu" for each
  gift: `Mystery_gift.open_gifts`, `open_internet_list`, `choose_gift`, the card, then all the way
  out (B off the card, B and yes to "stop receiving?", B and yes to "disconnect?", A past
  "disconnected", B off Link Play) and back in for the next gift. The cooldowns of that way out
  and in alone sum to about 25 s a gift (`mystery_gift.ml`: `stop_list`, `leave_link`,
  `open_gifts`, `to_internet`), though the next gift is two rows down the list the card came from.
- **The exits were blind.** A fixed B, A, A, B to leave pressed A on the gift list and claimed an
  unwanted gift (console B, 2026-11-25). https://github.com/dayfine/GamePilot/pull/251 fixed it by
  hand with `Leave_gifts`: classify the screen, pick the press for it, 12 presses at most.
- **The same walk is written four times.** `Leave_gifts.press_for` (PLZA), `Pc_box.open_next` and
  `leave_next` (FRLG: "not an ordered list of presses: each step looks at the screen and decides
  the next press"), `Menu_rows.goto` (PLZA main menu rows) and `Cursor_steps.step_to` (FRLG
  cursors) are each a read, one press toward a target, a read. `test_gift_console.ml`'s
  `next screen button` is the Mystery Gift graph already, written as a test fake.
- **FRLG.** 48 doc comments under `frlg/actions/lib` start "From the overworld"; `Member_level`,
  `Summary_moves`, `Fly_user`, `Party_species` and `Wild_rng_steps` each open the party and end in
  `Menu_input.close_to_overworld`. `Summary_paging.each_member` is the one that stays inside (DOWN
  on the info page to the next member), and it is its own module because nothing general does it.

## Decisions

1. **A game declares its screens and the presses between them; one `go_to` walks them.** The
   graph type, the path search and the walk are game-agnostic (`core/screen_graph`). A game gives
   a screen type, a reader and an edge function. Nothing in the library names a game, a menu or a
   button meaning.
2. **A screen is a value of the game's own variant, parameters included**: `Main_menu 5`,
   `Gift_list 3`, `Summary { slot = 2; page = Info }`. Edges are a pure function
   `edges : 'screen -> 'screen edge list`, not a table, so `Main_menu r` gives Down to
   `Main_menu ((r + 1) mod 6)` once, for every `r`. The search is a breadth-first search over it
   (the graphs are tens of screens), which also finds `Menu_rows.moves`' shorter way round.
3. **One reader per graph, and it answers with candidates.** `read : Wire.frame -> 'screen list`:
   every screen the frame could be, `[]` when it reads as none. Not one predicate per screen: the
   readers overlap and their order matters (`Leave_gifts.screen` checks the main menu, then the
   card, then the question, then the message; `Home_screen.read` and `Pc_deposit_steps.look` are
   the same shape). And some screens cannot be told apart at all: "stop receiving?",
   "disconnect?" and (as #251 assumes) "write a report?" are the same question box, where A means
   leave, leave and *save*; FRLG's box screen with a Pokémon's data shown reads as the overworld
   (`Pc_box.opening.chosen` exists for this). So the walk settles a look-alike by where it came
   from: after a hop, the screen is the hop's `leads_to` if that is among the candidates. With no
   hop before it (the first read, or after a lost one), several candidates count as unread.
4. **A read counts once it has held.** A screen change counts when the same candidates have read
   for 1 s (`Held_screen.held`, as every gift screen today: a white fade reads as the list for a
   moment). An edge that only moves a cursor on a steady screen says `First_read` and counts on
   the first frame that reads its target, as `Menu_rows.on_row` and `choose_gift` do today: six
   Downs must not cost six seconds.
5. **One hop, then read.** `go_to`: read (held); if the screen is the target, done; search; send
   the first hop's input; wait for a known screen to hold; repeat. Landing somewhere else that is
   known is not a failure, the next round plans from there. Still on the same screen means the
   press was lost (FireRed drops a tap while a menu slides in, `Cursor_steps`), and the same round
   presses again. A hop budget ends it (default 40, `Pc_box.max_looks`).
6. **Edges that do something are marked and never walked through.** An edge is `Transit` or
   `Acts of string` (`"claim"`, `"save"`, `"release"`). The search uses `Transit` only. A program
   takes an acting edge by name with `take`, which first requires its source screen to have held:
   the A that claims is pressed only on `Gift_list k` read with the gift on row `k`.
7. **An unread screen gets no press, unless the game declares one that is safe everywhere.**
   Unread within the timeout fails with the last reading. This is where the code pushes back on
   "fail on unknown": #251 presses B on `Other` because Link Play has no reader, and
   `Pc_box.leave_next` presses B on anything that is not the overworld or a fade. So a graph may
   declare `when_unread = Press b` with the reason in its doc (PLZA gifts: B opens at worst a
   question whose default the walk then reads), used at most three times in a row; the default is
   `Fail`. Each screen that gains a reader shrinks its use (question 1).
8. **An edge's input is normally one press.** It may be several only across a screen with no
   reader yet, and its doc says which (today: Link Play, between `Main_menu 5` and `Gift_menu`:
   A, Right, Right, Down, A, as `open_gifts`; #251 already lists it as known and left).
9. **Errors are values.** `go_to` and `take` return a `Result`; the failure says the screen it was
   on, the target, and the last frame's reading (`describe`). No new exception; the effects
   boundary's own pass through as today.
10. **Programs say where they need to be, not where they start.** An action begins with `go_to`
    its screen and leaves the game where its work ended. Recovery is `go_to` the graph's `home`
    (the main menu, the overworld). No plan format change: screens stay inside game actions
    (question 3).

## The library

`src/core/screen_graph/lib`, beside `screen_state` (pure scene rules) and `switch_home`
(`Held_screen`, `Timed_press`). Not `engine/`: the engine is the checkpoint engine and knows plans,
not screens; this is what a game action calls, and Switch HOME (a `core` library) is a user too.

```ocaml
(* Screen_graph: the type, the search, the check. Pure; depends on wire only. *)
type arrive = Held of int | First_read
type kind = Transit | Acts of string

type 'screen edge = {
  input : Wire.command list;  (* a press or a tilt, with its hold and cooldown *)
  leads_to : 'screen;
  arrive : arrive;
  within_ms : int;
  kind : kind;
}

type when_unread = Fail | Press of Wire.command list

type 'screen t = {
  name : string;
  probes : Wire.probe_spec list;
  read : Wire.frame -> 'screen list;
  edges : 'screen -> 'screen edge list;
  screens : 'screen list;  (* every screen, parameters expanded *)
  home : 'screen;
  when_unread : when_unread;
  show : 'screen -> string;
  describe : Wire.frame -> string;
}

val path : 'screen t -> from:'screen -> at:('screen -> bool) -> 'screen edge list option
val check : 'screen t -> (unit, string) result
```

```ocaml
(* Screen_walk: the deciding module. *)
type 'screen game_steps = {
  read_screen : hold_ms:int -> within_ms:int -> 'screen list;  (* held; [] when none did *)
  send : Wire.command list -> unit;
  log : string -> unit;
}

type 'screen failure =
  | Unread of { last : string }
  | No_path of { from : 'screen }
  | Out_of_hops of { on : 'screen }
  | Not_on of { wanted : 'screen; last : string }  (* take: its source did not hold *)

val go_to :
  'screen Screen_graph.t -> 'screen game_steps -> at:('screen -> bool) ->
  ('screen, 'screen failure) result
val take :
  'screen Screen_graph.t -> 'screen game_steps -> from:'screen -> string ->
  ('screen, 'screen failure) result
```

- The target is a predicate, so "on the gift list, any row" is one call and the nearest such
  screen wins; `go_to` returns the screen it reached. `Screen_graph.exactly s` for one screen.
- `take` returns the screen that held after the act: any known one, not only `leads_to` (a claim
  ends on the card, or on "already received").
- `game_steps` per the hard rule: `Screen_walk_steps.make graph` builds it on the effect set
  (`Held_screen.wait_for`, `Effects.await`, `Effects.submit`), run inside
  `Effects.with_probes graph.probes`; tests pass a `fake_game_steps` over a list of reads.
- `Screen_graph.check`: every `leads_to` is in `screens`; every screen reaches `home` by `Transit`
  edges alone; act names are unique per source. A unit test per graph, so a new screen with no way
  out fails in CI, not on the console.

## Where a game's graph lives

`src/games/<game>/screens/lib` (PLZA: `games/pokemon/plza/screens`), one module per menu tree, each
a graph with its own probes: `Plza_screens.Gifts` first. One per tree, not one per game, because
the first read needs every probe of the graph subscribed and a whole game's would be dozens (the
field, the battle HUD, the Boxes). Trees share a screen where they meet (`Main_menu r`), and a
program walks one graph to that screen and the next from it.

The gift tree, from `test_gift_console.ml`'s `next` and #251's readers:

| Screen | Reads as | Transit | Acts |
|---|---|---|---|
| `Main_menu r` | `Main_menu_row.highlighted` | Down, Up (`First_read`); `r = 5`: the five presses of decision 8 to `Gift_menu`; B to the field | |
| `Gift_menu` | `gift_menu` | B to `Disconnect` | A: `"connect"` (goes online; may ask to save) |
| `Gift_list k` | `list_active`, `selected_item` | Down, Up (`First_read`); B to `Stop_receiving` | A: `"claim"` |
| `Card` | `card` | B to `Gift_list` (console B, 2026-11-25) | |
| `Stop_receiving`, `Disconnect`, `Write_report` | `question` (one look) | No highlighted: Up. Yes: A to `Gift_menu` / `Disconnected` (not `Write_report`: its A is `"save"`) | |
| `Disconnected`, other messages | `message` | A (then B over Link Play) to `Main_menu 5` | |
| `Keyboard` | `Code_keyboard.shown` | B to `Gift_menu` | `"enter"` (+) |

The exact edges are settled in the PR against the captures; what is not captured stays listed as
it is in #251 ("disconnect?", "disconnected", a list after a code).

## The two examples

**Claim-gifts, staying inside Mystery Gift.** `Claim_gifts.game_steps.claim` keeps its type; what
it does changes from "main menu to main menu" to:

```ocaml
let claim_one g steps gift =
  let* _ = W.go_to g steps ~at:on_gift_list in           (* from wherever the last gift left us *)
  let* k = gift_row gift in                              (* Mystery_gift_screen.gift_item *)
  let* _ = W.go_to g steps ~at:(exactly (Gift_list k)) in
  let* after = W.take g steps ~from:(Gift_list k) "claim" in
  match after with Card -> Ok Received | ... -> Ok (Not_received (g.show after))
```

For the first gift `go_to on_gift_list` walks main menu, Link Play, Mystery Gift, and the program
takes `"connect"`; for the next it is B off the card (the cursor is read, not assumed). A code
gift after an Internet one is B, yes, Down, A to the keyboard, not the link dropped and remade.
After the last gift, and after any failure, `go_to (exactly g.home)`: `Leave_gifts.to_main_menu`
is that call, and `Gift_claim.back_to_menu`, `Mystery_gift.leave_list` and `disconnect` go.
`Lost` stays: it is `go_to home` failing.

**Party members (FRLG).** Screens `Overworld`, `Start_menu r`, `Party slot`, `Member_menu r`,
`Summary { slot; page }`; DOWN on the info page leads to `Summary { slot + 1; page = Info }`
(pokefirered `SeekToNextMonInSingleParty`), LEFT and RIGHT turn pages. A read becomes
`go_to (exactly (Summary { slot; page = Moves }))` then the read itself: from the overworld that
is the whole way in; from member 2's info page it is DOWN, RIGHT. Reading six levels and six move
lists is one entry and one exit with no `each_member` wrapper, and `Fly_user` followed by
`Member_level` no longer closes and reopens the party between them. Whoever needs the field next
says `go_to (exactly Overworld)`.

## Tests

- `core/screen_graph/test`: `path` and `check` on toy graphs; `go_to` on `fake_game_steps`: a
  lost press, a landing elsewhere, look-alikes settled by the hop, an ambiguous first read, the
  unread press and its limit, the hop budget, an acting edge never on a path.
- Per graph: `check`; every fixture frame's `read` (the gift captures in
  `readers/test/fixtures/gifts`); and the graph against the scripted console's own `next`, which
  stays hand-written from what console B did (a fake derived from the graph would prove nothing).
- #251's fake-console tests (no A on the list but the claim's own, "stop receiving?" already
  open, an item's card, a wrong Link Play option) must pass unchanged on the migrated code.
- Wire-log replay needs nothing new: the walk is a function of the frames, and a different press
  is a `Replay.Divergence`.

## Migration

Each step its own PR; the first two change no behaviour.

1. `core/screen_graph` with its tests (a new library: structural).
2. `Plza_screens.Gifts` and its tests, after #251 merges; `Leave_gifts.to_main_menu` becomes
   `go_to home` with the same presses, checked by #251's tests.
3. The gift loop stays inside Mystery Gift (the example above). A gift is claimed once a save, so
   its console proof is the next save's run and that run's wire-log replay, not three passes.
4. PLZA `Boxes` and `Save_dialog` join the main-menu tree (`Gift_boxes`, `Save_progress`: "from
   the main menu back to it"); then Pokémon HOME's menus for bank-home (`pokemon/home`, ours).
5. FRLG party and summary: the five `close_to_overworld` callers and `Summary_paging`, tested on
   mGBA; `Menu_cursor` and `Cursor_steps` become `First_read` edges. It returns `Result`, so it
   goes with `Menu_input.Action_failed`'s conversion, not before it.
6. FRLG PC (`Pc_box.open_next`, `leave_next`): the look-alike rule replaces `opening`.

Stays hand-written: ported fork code, which keeps the C++'s steps (`Switch_home.Game_entry`, the
talk and scene rules in `screen_state`, battles); anything timed rather than read (RNG presses,
ACE); walking (the navigation grid is its own graph); typing (`Code_keyboard`); work inside one
screen (the Y, move, Y of `Gift_boxes`); and menus with no cursor reader (a bag item's menu, a
Mart's list), which count presses until they have one.

## Settled questions

The user took each recommendation (2026-11-26, "take the doc's recommendation").

1. **The unread press** (decision 7): a graph may declare B on an unread screen, as #251 and
   `Pc_box.leave_next` do today, capped, and every use is logged so each is a reader to write.
2. **#251 merged first** (476816cf); step 2 replaces `Leave_gifts` under its tests.
3. **Plans do not name screens yet**: a format change that belongs with composing programs
   (`Story-Flags.md`, decision 5).
4. **`Held_screen` moves to `screen_graph`** in step 1 (a rename, structural); its users are
   `switch_home` and claim-gifts.
5. **PLZA first**: steps 2 to 4 (gifts, the gift loop, Boxes/Save/HOME), then FRLG's party once
   `Action_failed` is a `Result`.
