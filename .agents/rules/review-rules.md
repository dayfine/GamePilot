---
harness: project
---

# Review rules — GamePilot

The general rules the user has stated in reviews, one entry each, so they can be checked on new
PRs (qc-structural reads this file) and audited across the tree now and then (the `rule-audit`
agent, `.agents/agents/rule-audit.md`; how to run it: `dev/review/rule_audit.md`).

Each entry: the rule in one sentence; why, with the date and where it was said; a bad and a good
example; and how to find it. Text in quotation marks is the user's own words, linked where they
were written; words said in a working session, with no page to link, say so instead of a link. A
call the user made without words worth quoting is paraphrased, without quotation marks, and links
a PR only where it was applied. "How to find it" is a lint or check name when
one exists; else a recipe an auditor runs from the repo root (its hits are candidates, to be
confirmed by reading); else "judgment" with what to read.

A new rule is added here when the user's review comment states a general rule (AGENTS.md, "PR
gate loop"). Ids are never reused; a retired rule keeps its id with "Retired:" and why.

The hard rules in `AGENTS.md` that a lint already enforces (function and file length, nesting,
magic numbers, `.mli` coverage, layers, `never_links`, no exceptions, no C in OCaml, the opam
allowlist) are not repeated here. Those no lint checks yet are linked in the last section.

## From the review of #109 (FRLG ACE setup, 2026-11-25)

### R1 A doc says what a thing does, never a list of what plugs in

A doc comment does not enumerate the other modules or entries that register with the thing (a list
that must grow with every addition); it says what the thing does.

- Why: "noisy change -- we should just drop the listing" (user, 2026-11-25, on
  `game_actions.mli`: https://github.com/dayfine/GamePilot/pull/109#discussion_r4697763368).
- Bad: `(** One handler per {!Action_requests.names}; then mg-06's ({!Mail_glitch_use.handlers})
  and the Rare Candy ones ({!Candy_actions.handlers}). *)`
- Good: `(** Every FireRed game action a plan can name, by its name. *)`
- Find: lint `doc_listing` (`dev/lint/ocaml_lint.conf`, `doc_listing handlers`): an `.mli` doc
  comment that cross-references one registration value in two or more modules. Lists in prose
  ("the Mail Glitch, Rare Candy and ACE actions") or of other value names: judgment, reading the
  doc comments of modules that gather others (`grep -rln --include='*.mli' -E '\{![A-Z]' src`
  and the `.mli`s of registries, action tables and `*_actions` modules).

### R2 Generated guide needs leave out zero or empty requirements

A need any save meets (0 free party slots, an item or money at least 0, an empty list) is no need,
and the generated guide blocks do not print it.

- Why: "if it's 0 then it's not a requirement and we should not mention it" (user, 2026-11-25:
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697777309).
- Bad: `- 0 free party slots` in a guide's `needs` block.
- Good: the line left out; `- 2 free party slots (joining: ...)` when slots are needed.
- Find: the generator (`src/games/frlg/series/lib/guide_tables.ml`,
  `Frlg_checkpoints.Plan_needs.asks_something`)
  leaves them out and CI's `gamepilot guide --check` fails on a stale block. A new kind of need
  must say in `asks_something` when it asks nothing. Recipe for leftovers:
  `grep -rnE '^- 0 |x0\b|¥0\b|at least 0' docs/guide`.

### R3 A plan states needs as capabilities or roles, not incidental species

What a plan needs of the save is said as the capability it uses ("a member that knows Fly", "a free
party slot", "a member with no mail record"), never as the species that happened to provide it in
the run the plan was written from. A species is named only when the story needs that species.

- Why: "do we simply need *a* flying user? at which spot? is the species required to be exact?"
  and "do we just need a mail user?" (user, 2026-11-25:
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697782820,
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697784353).
- Bad: `pidgey in the party (fly)`; `party includes ... mr-mime in slot 3` when any member with no
  mail would do.
- Good: `a member knows Fly (fly)`; `a member holding no mail`.
- Find: recipe, then judgment on each hit (is the species part of the story, a trade's offer, or
  only the member the action used?):
  `grep -rnE '"species"|"party_includes"|"party"' src/games/*/programs/*/plans` and
  `grep -rnE 'in the party \(|party includes' docs/guide`.

### R4 A program's first checkpoint starts anywhere sensible

The first checkpoint of a program accepts any start the story allows (anywhere outdoors where Fly
works, say), not the tile the author stood on, unless the story truly needs that spot; it walks or
flies from wherever the player is.

- Why: "location shouldn't matter as we can fly?" and "start can really be `any` or `outdoor`?"
  (user, 2026-11-25: https://github.com/dayfine/GamePilot/pull/109#discussion_r4697786807,
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697866247).
- Bad: a program whose first plan starts at `CeladonCity_DepartmentStore_1F (6, 2)` and then flies
  away.
- Good: the first checkpoint starts outdoors anywhere Fly works and flies to where it needs to be.
- Find: recipe, then judgment (does the first event need the spot, or does it leave it?):

  ```sh
  python3 -c 'import json,glob
  for d in sorted(glob.glob("src/games/*/programs/*/plans")):
      f = sorted(glob.glob(d + "/*.plan.json"))[0]
      s = json.load(open(f))["checkpoint"]["start"]
      print(f, s.get("map"), s.get("tiles"))'
  ```

  The fix may need the plan format to say "outdoors" or "any": that format change is structural
  and goes first, in its own PR.

### R5 Each event is skipped when the game already holds its result

An event whose result the game can already hold (a member caught or traded, an item bought or
picked up, a mail written) carries a `skip_if` on that game state, so a rerun or a different save
does not do it twice. No plan assumes its save came from one particular earlier run, unless it says
so as a checked precondition.

- Why: "what if we already have Magikarp?" and "huge assumptoin [sic] which might be wrong",
  "this assumes it's' [sic] chained from the particular mail glitch setup we used?" (user,
  2026-11-25: https://github.com/dayfine/GamePilot/pull/109#discussion_r4697876656,
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697884303). Earlier, the user's call
  on the Sevii start (2026-11-24, in a working session), paraphrased: a program checks its
  preconditions instead of needing a special save.
- Bad: a `catch` event for Magikarp with no `skip_if`; a plan's notes saying "the party from mg-08"
  with no precondition checking it.
- Good: `"skip_if": ["magikarp_in_party"]` on the catch; `metadata.preconditions` (or a
  postcondition of the checkpoint before) stating the party it needs.
- Find: recipe, then judgment on each event (can the game already hold its result?):

  ```sh
  python3 -c 'import json,glob
  for f in sorted(glob.glob("src/games/*/programs/*/plans/*.plan.json")):
      for e in json.load(open(f))["checkpoint"]["events"]:
          if e.get("kind") in ("game_action", "talk", "pickup") and "skip_if" not in e:
              print(f, e["id"], e.get("action", e.get("kind")))'
  grep -rnE 'from (mg|tt|su|sb)-[0-9]+|chained|as left by|the save from' src/games/*/programs/*/plans
  ```

### R6 One doc page per program: its guide

A program has one page, `docs/guide/<program id>.md`; the developer's reasoning goes in its "How it
works" section. There is no separate `docs/programs/<program>.md` page.

- Why: "huh ok, so we have docs/guide/frlg.ace_setup.md and we have this?" (user, 2026-11-25:
  https://github.com/dayfine/GamePilot/pull/109#discussion_r4697827206).
- Bad: `docs/programs/frlg-supplies.md` beside `docs/guide/frlg.supplies.md`.
- Good: `docs/guide/frlg.supplies.md` with a "How it works" section; the descriptor's `doc` points
  at it.
- Find: recipe (every hit is a finding; the folder is gone, and adding a program is in
  `docs/guide/README.md`): `ls docs/programs/` and
  `grep -rn 'doc = "docs/programs/' src/program_registry/lib`.

## From the user's earlier structural calls

### R7 Names say what a thing is or does

A name explains itself without the PR for context: no private jargon, no format where the job
belongs, no "story" on what is not story-specific, and a conversion's name says its direction.
(`AGENTS.md`, hard rule "Names say what a thing is or does", is the base rule; this adds the
cases the user called out.)

- Why: "what is a `rig`? can it be an easier-to-understand naming?" and "what's only does here?"
  (user, 2026-11-24: https://github.com/dayfine/GamePilot/pull/30#discussion_r4688349381,
  https://github.com/dayfine/GamePilot/pull/30#discussion_r4688361342); "what does _look really
  mean?" and "what does no_end really mean?" (user, 2026-11-25:
  https://github.com/dayfine/GamePilot/pull/89#discussion_r4693210307,
  https://github.com/dayfine/GamePilot/pull/89#discussion_r4693212720); "let's really take a moment
  and scrutinize the names" (user, 2026-11-25, in a working session; the renames applied in #89);
  "_text really stands out as not obvious" (user, 2026-11-25, in a working session; applied in
  #97). The user's calls in working sessions, paraphrased: drop `story` from GamePilot names, since
  goal programs like the Mail Glitch are generic (2026-11-24); a `*_json` name is too vague, it says
  the format, not the job (2026-11-25, applied in #97); a conversion's name says its direction
  (2026-11-25, applied in #77).
- Bad: `Walk_look`, `no_end`, `story_runner` for a goal program's runner, `plan_json`, `convert`.
- Good: `Walk_screen`, `Last_leg_end`, `checkpoint_runner`, `plan_format`, `of_plan`/`to_text`.
- Find: judgment on new and renamed modules; recipe for the known offenders:
  `grep -rnE --include='*.ml*' '\b[a-z_]*(_look|_only|_json|story)[a-z_]*\b' src | grep -v '/test/'`
  (story is fine where the thing is story-specific, e.g. `sevii_story`).

### R8 The record of game reads and actions is `game_steps`

`AGENTS.md`, hard rule "What a deciding module reads and does in the game is its `game_steps`".

- Why: "what is a `rig`? can it be an easier-to-understand naming?" (user, 2026-11-24:
  https://github.com/dayfine/GamePilot/pull/30#discussion_r4688349381). The user's call on the
  naming convention (2026-11-24, in a working session), paraphrased: one name anyone can grep for,
  and not `handler`, which clashes with effect handlers.
- Bad: `type candy_rig = { read_party : ...; press : ... }`.
- Good: `type game_steps = { read_party : ...; press : ... }`, built by `candy_game_steps`, faked
  by `fake_game_steps`.
- Find: recipe, then judgment (is the hit a record of game steps?):
  `grep -rnE --include='*.ml*' '\b(rig|driver|ops|callbacks)\b|type [a-z_]*(deps|handlers) = \{' src`.

### R9 A port's doc comment names the source files, not their functions or constants

A ported module's doc comment names the C++ (or pret) file(s) it comes from, so the two can be laid
side by side, and says where it differs; it does not name the fork's C++ functions, classes or
constants. pret is the exception: its files are long, so a doc comment may name the pret function,
table or constant it follows (`naming_screen.c`'s `sKeyboardChars`), with the file.

- Why: "let's not refer to the old C++ symbols" (user, 2026-11-25:
  https://github.com/dayfine/GamePilot/pull/89#discussion_r4693220866). The base rule is `AGENTS.md`, "Port the C++
  transparently".
- Bad: `as upstream's [use_rare_candy()] watches for it: ... its PartyLevelUpWatcher`.
- Good: `as upstream's PokemonFRLG_RngNavigation.cpp does after a Rare Candy: the stats window ...`.
- Good (pret): `the key grids of pret's naming_screen.c (sKeyboardChars)`; pret symbols allowed
  (user, 2026-11-25, on #208's qc FLAG).
- Find: recipe over the files that name a source file, then judgment:

  ```sh
  grep -rlE --include='*.ml*' '\.(cpp|h|c)\b' src | xargs grep -nE \
    '[A-Za-z_]+\(\)|\b[A-Z][a-z]+([A-Z][a-z]+)+(Watcher|Detector|Reader|Session|Program)\b|\b[A-Z][A-Z0-9_]{4,}\b'
  ```

### R10 One decision lives in one module; contexts supply only what they read

A decision taken in several contexts (level-up: learn, forget, evolve) lives in one shared module,
with its checks; each context supplies only its readers and inputs, never its own copy of the
decision.

- Why: the user's calls while reviewing the Rare Candy work (2026-11-24, in a working session),
  paraphrased: the Rare Candy and post-battle level-ups share one level-up module, and its shared
  checks (the evolution YES/NO) live there by default, each context supplying only its readers.
  Applied in #30 (`Level_up`).
- Bad: the battle and the Rare Candy actions each answering the evolution YES/NO box.
- Good: `Level_up` decides; `candy_game_steps` and the battle's steps supply the screens.
- Find: judgment. Read modules that answer the same prompt or screen
  (`grep -rnE --include='*.ml' 'yes_no|evolution|forget|learn_move' src/games | cut -d: -f1 | sort | uniq -c`)
  and the S7 FLAGs of past qc-structural reviews.

### R11 Every type and val in an interface is documented for a newcomer

Every `type`, constructor and `val` in a `lib/` `.mli` has a doc comment a newcomer understands,
and text read from the game screen names its language risk. (qc-structural row S5.)

- Why: "again, what's right and why doesn't have a comment for itself?" and "risk of the dialogue
  is of various length in different languages? let's document clearly" (user, 2026-11-24:
  https://github.com/dayfine/GamePilot/pull/30#discussion_r4688400289,
  https://github.com/dayfine/GamePilot/pull/30#discussion_r4688370726). Supporting every language
  is a standing goal.
- Bad: `type verdict = As_asked | Wrong of string | Unread of string` with no doc line.
- Good: `(** What the box screen says about the checked slot. *)` above it.
- Find: lint `interface_docs` (`dev/lint/ocaml_lint.conf`, `interface_docs src`): every `type`,
  `val`, variant constructor and `exception` in a `lib/` `.mli` needs a doc comment the compiler
  attaches to it (right before or after, no blank line between); a constructor may instead be
  named in its type's doc (a re-exported variant's are documented where defined), and a record documented only through its fields is a finding. Files
  with gaps on the day it landed are waived file by file in `dev/lint/ocaml_lint_exceptions.conf`
  (a list that only shrinks), so in a waived file, new items are judgment: run the check with the
  file's line removed. Whether a doc says what a thing means, and the language risk of screen
  text, are judgment:

  ```sh
  find src/games -path '*/lib/*.ml' \( -path '*/readers/*' -o -path '*/text/*' \
    -o -path '*/actions/*' -o -path '*/battle/*' \) | \
    xargs grep -lE '"[A-Z][a-z]+ [a-z]+.*[?!.]"' | xargs grep -L -iE 'language|english'
  ```

### R12 Tests check one fact per expectation and say what their fakes are

A test's expectation is one fact; a long expected string that packs several (a whole trace, a
multi-line log) is split. Each test file says what its fakes stand in for. (qc-structural row S6.)

- Why: "what is this? it's a really long string" (user, 2026-11-24:
  https://github.com/dayfine/GamePilot/pull/30#discussion_r4688422803), answered by splitting the
  case into one expectation per member.
- Bad: `check "trace" (String.concat "\n" trace) "press A\nread menu\npress down\n..."`.
- Good: one case per press and per reading.
- Find: recipe, then judgment:
  `grep -rnE --include='*.ml' '\\n[^"]*\\n[^"]*\\n' src/*/*/test src/*/*/*/test src/games/*/*/test | grep -vE 'failwith|Printf'`
  and test files without a top comment (`for f in $(find src -path '*/test/*.ml'); do head -1 "$f" | grep -q '^(\*' || echo "$f"; done`).

### R13 Repeated plan steps become named places; a place has one spelling

Steps repeated across plans ("walk to the lift, ride to 4F, walk to the clerk") are a named place
and a `go_to`, not copies; places and towns are typed keys in the places table, never names built
from strings.

- Why: "how do we dedup'd the go-to-XF of department store?" and "code abstraction? data
  composition?" (user, 2026-11-24: https://github.com/dayfine/GamePilot/pull/25#discussion_r4688693488).
  The user's call on the town key (2026-11-24, in a working session), paraphrased: one spelling per
  town and no place names built from strings, typed keys over naming conventions; applied in #40.
- Bad: the same three events in `su-01` and `tt-01`; `town ^ "_nurse"`.
- Good: `{"kind": "route", "args": {"place": "celadon_dept_4f_clerk"}}`; `towns.celadon.nurse`.
- Find: recipe for runs of three identical events in two plans, and string-built place names:

  ```sh
  python3 -c 'import json,glob,collections
  seen = collections.defaultdict(set)
  for f in glob.glob("src/games/*/programs/*/plans/*.plan.json"):
      ev = [json.dumps({k: v for k, v in e.items() if k not in ("id", "why")}, sort_keys=True)
            for e in json.load(open(f))["checkpoint"]["events"]]
      for i in range(len(ev) - 2): seen["|".join(ev[i:i + 3])].add(f)
  for k, fs in seen.items():
      if len(fs) > 1: print(sorted(fs), k[:160])'
  grep -rnE --include='*.ml' '\^ "_|"_" \^|\^ "(nurse|mart|center|fly)' src
  ```

### R14 Programs are configurable, validate their input and check preconditions first

What a player would choose (a shopping list, a count, a target level) is a program option, not a
literal; the input is validated (no Master Ball on a shopping list); and the pre-flight refuses
before the first event, naming the missing fact and the checkpoint that provides it.

- Why: "should it be configurable?", "prerequisite is flying and money (do we check from trainer
  card)?" and "it should now [sic] how to go to different locations or reject invalid items (e.g.
  master balls)?" (user, 2026-11-24: https://github.com/dayfine/GamePilot/pull/25#discussion_r4688670416);
  "decisions must be predefined" (user, 2026-11-24, in a working session on level-ups). The user's
  call on unmet needs (2026-11-24, in a working session), paraphrased: refuse before the first
  event, naming the missing fact and the checkpoint that provides it.
- Bad: a plan buying a hard-coded 30 Ultra Balls; a run that fails at event 12 because money ran
  out.
- Good: `--count 30` with a default, validated; the pre-flight's `money at least ¥36000` row.
- Find: judgment. Read each program's plans for counts, targets and lists a player would set
  (`grep -rnE '"(quantity|count|target_level|level)": *[0-9]{2,}' src/games/*/programs/*/plans`)
  and each guide's "Before you start" block for a need the pre-flight does not check.

### R15 Supplies are stocked beyond the immediate need

A program that stocks or duplicates an item makes more than the next step uses, so later steps
never run short.

- Why: the user's call on team training's tt-01 (2026-11-24, in a working session), paraphrased:
  duplicate more than the immediate need, so later steps never run short.
- Bad: duplicating exactly the 8 Retro Mail the next checkpoint gives away.
- Good: duplicating to 99 and leaving the rest in the bag.
- Find: judgment. Compare each stocking checkpoint's `gained` postcondition with what later
  checkpoints spend: `grep -rnE '"(gained|spent|quantity)"' src/games/*/programs/*/plans`.

### R16 Nothing is shared before a second user exists

Code moves to a shared layer (`src/pokemon`, `src/engine`, a cross-game folder) when a second game
or program uses it, not before; until then it lives with its one user.

- Why: on where the RNG goes: "each game's mechanism is different ... then we need to invent some
  gen directory" (user, 2026-11-24, in a working session; applied in #24). The call, paraphrased:
  keep it in `games/frlg/rng`, and share nothing before a second user exists.
- Bad: `src/pokemon/rng/` holding FireRed's seeding with FireRed its only caller.
- Good: `src/games/frlg/rng/`, moved when a second Gen 3 game needs it.
- Find: recipe, then judgment: for each library under `src/pokemon` and `src/engine`, the
  top folders whose `dune` files link it (one game, or only its own layer, is a candidate; a
  library a shared one links is used through it, so follow the chain):

  ```sh
  for d in $(find src/pokemon src/engine -name dune -path '*/lib/*' -not -path '*/_build/*'); do
    n=$(sed -n 's/.*(name \([a-z_]*\)).*/\1/p' "$d" | head -1)
    echo "$n: $(grep -rlw "$n" --include=dune src | grep -v _build | grep -v "^$d$" |
      cut -d/ -f2-3 | sort -u | tr '\n' ' ')"
  done
  ```

### R17 One kind of command with optional fields, not a second kind

When a command or case needs an extra, optional part, the existing case gets an optional field;
no parallel `X_with_y` case.

- Why: "we don't need a second kind of press" (user, 2026-11-25, in a working session; applied in
  #59): one wire command, one OCaml case.
- Bad: `Press of press | Press_with_sticks of press * sticks`.
- Good: `Press of { ...; left_stick : stick option; right_stick : stick option }`, built by
  `Wire.press ?left_stick`.
- Find: recipe, then judgment: `grep -rnE --include='*.ml*' '\| *[A-Z][a-z_]*_with_[a-z_]+' src`.

### R18 A value fixed for a run is an input, not a query

What does not change during a run (the backend's picture, the game size) is passed to the program
once, as an argument, not read through an effect or a new query.

- Why: the user's call (2026-11-25, in a working session), paraphrased: a value fixed for a run is
  an input, not a query. Applied in #86 (`run_with_backend ~picture`).
- Bad: a `read Picture` effect the program calls before each walk.
- Good: `run_with_backend ~picture` handing it to the program at start.
- Find: judgment. Read new effects and probe kinds, and readers called with the same arguments on
  every step (`grep -rnE --include='*.ml' 'Effects\.read .*(viewport|picture|game_size|backend)' src`).

### R19 A result with several meanings is a variant, not an option or a bool

A function whose answer has more than two meanings returns a variant naming each (`verdict`),
not `result option` or a pair of bools.

- Why: the rename list the user approved (2026-11-25, in a working session) gave `Last_leg_end` a
  verdict type instead of a result option; applied in #89.
- Bad: `val last_leg_end : ... -> (pose, string) result option`.
- Good: `type verdict = Arrived of pose | Off_route of string | Not_yet`.
- Find: recipe, then judgment: `grep -rnE --include='*.mli' 'result option|bool \* bool|option option' src`.

### R20 Pure rules are kept apart from I/O conversions

A game's rules, plan types, runner and checks link no JSON or text library; formats live in their
own codec, text and saved-state modules, converted at the edge.

- Why: "my main concern is layering -- there is lots of I/O conversions here which I'd prefer to
  isolate" (user, 2026-11-25, in a working session; applied in #77).
- Bad: `Pokemon_rules` calling `Yojson.Safe.to_string` in a failure message.
- Good: failures carry values, rendered to text by the text module.
- Find: lint `never_links` covers the libraries listed in `dev/lint/ocaml_lint.conf`. For new
  rules libraries not yet listed: judgment, reading `dune` files under `src/*/checkpoints/` and
  `src/games/*/checkpoints/` for `yojson`, `json_field` or `*_text`.

### R21 Proof fixtures go once the run they proved passed

Fixtures kept only to prove a change on mGBA or the console (before/after captures, one-off logs)
are deleted once that run passed; the unit tests that pin the behaviour stay.

- Why: the user's call on the `before/` fixtures (2026-11-24, in a working session), paraphrased:
  delete them now that mGBA passed and keep the expansion unit tests, since proof fixtures go stale.
  Applied in #39 and #40.
- Bad: a `before/` folder of expanded plans beside the expansion tests.
- Good: the expansion tests alone.
- Find: recipe, then judgment (is any test or doc reading it?):
  `find src docs -type d \( -name before -o -name after -o -name proof \)` and
  `git ls-files src | grep -E '\.(png|jsonl\.gz|log)$'` checked against the `dune` files that
  name them (`grep -rn <basename> --include=dune src`).

### R22 Plan files have short descriptive names

A plan file is its order number and one to five words saying what it does, with species names,
not nicknames: `03-trade-mr-mime.plan.json`, not `mg-03.plan.json`. Where the game numbers its own
steps (PLZA's story rows), the order number is that `NN.NN` numbering, a split's letter kept:
`03.02b-battle-taunie.plan.json`; otherwise it is `NN`.

- Why: the user's calls on plan file names (2026-11-24, in a working session), paraphrased: short
  descriptive names, one or two words ideally and at most five, using species, not nicknames;
  applied in #43. `su-01` and `tt-01` keep their ids until their programs are split by goal. On PLZA
  (2026-11-25): the story's own number in front, so a plan, a console run and the fork's checkpoint
  share it.
- Bad: `mg-03.plan.json`, `03-trade-mimien.plan.json`, `03.02b.plan.json`.
- Good: `03-trade-mr-mime.plan.json`, `03.08-fourth-species.plan.json`.
- Find: recipe (`su-01`, `tt-01` are known):
  `ls src/games/*/programs/*/plans src/games/pokemon/*/programs/*/plans | grep -vE '^[0-9]{2}(\.[0-9]{2}[a-z]?)?-[a-z0-9]+(-[a-z0-9]+){0,4}\.plan\.json$|:$|^$'`.

### R23 No runtime dependency on Packages; per-language assets are committed

Code reads game text and assets from files committed in this repo, one per language, never from
`third_party/Packages` at run time; every language is kept even when only English is tested.

- Why: the user's call on move names (2026-11-24, in a working session), paraphrased: no runtime
  dependency on Packages, per-language assets committed and every language kept, for CI and
  portability; languages matter even when untested.
- Bad: a reader opening `third_party/Packages/.../MoveNames.json` at start.
- Good: `src/games/frlg/text/assets/move_names.<lang>.json` committed, loaded per language.
- Find: recipe: `grep -rn 'Packages' --include='*.ml' --include=dune src | grep -v '/test/'`.

## From the review of #146 (review rules catalog, 2026-11-25)

### R24 A precondition names the game's own gate, not a proxy

A checkpoint's preconditions (declared in `metadata.preconditions` or derived from its events) name
what the game itself checks: a specific badge, a story flag, a key item. Never a proxy that
happened to hold on the save the plan was written from: a badge count, the Hall of Fame, a species.
Find the gate in pret pokefirered (the script or the C that checks it) and cite it.

- Why: the user's call while reviewing the rules catalog (2026-11-25, in a working session),
  paraphrased: what Sevii part 1 really needs is the Fire-type badge, and what lets us fly is a
  specific badge; those are the more specific and likely the correct checks for some checkpoints.
- Bad: Sevii 01 with `"preconditions": {"badges": 8, "hall_of_fame": true}`; a `fly` event that
  needs only `pidgey in the party (fly)`.
- Good: `"preconditions": {"badges": ["volcano"]}` (Blaine's win sets `FLAG_BADGE07_GET` and
  starts Bill's scene: `data/maps/CinnabarIsland_Gym/scripts.inc`); a `fly` event needing
  `the thunder badge (fly)` beside its member (`src/party_menu.c`: an HM outside battle needs
  `FLAG_BADGE01_GET` + its field move: Flash Boulder, Cut Cascade, Fly Thunder, Strength Rainbow,
  Surf Soul, Rock Smash Marsh, Waterfall Volcano; `Frlg_checkpoints.Plan_needs` derives it).
- Find: recipe, then judgment on each hit (is the count or the Hall of Fame what the game checks?):
  `grep -rnE '"(badges|hall_of_fame)": *(true|[0-9])' src/games/*/programs/*/plans`;
  for field moves, `grep -rnE '"action": "(fly|surf|strength|rock_smash|waterfall|cut_tree|flash)"' src/games/*/programs/*/plans`
  checked against `field_move_badges` in `src/games/frlg/actions/lib/action_args.ml`, and
  `grep -rnE 'in the party \((fly|surf|strength|cut)' docs/guide` for an HM need by species (R3).

## From the review of #198 (PLZA Main Mission 01.02–01.03, 2026-11-25)

### R25 A program's registry description says what it does, never how far it gets today

A program's `description` in `src/program_registry` says what the program does, not which
checkpoints, missions or steps it covers so far: coverage changes with every plan PR and is shown
by the plans and the guide's generated blocks.

- Why: "this doesn't need to change every single timme / This is leaking details" (user,
  2026-11-25, on `program_registry.ml`:
  https://github.com/dayfine/GamePilot/pull/198#discussion_r4702448448).
- Bad: `"Plays the story; for now from the new game's Confirm Choices through Main Mission 01
  (checkpoints 01.00b to 01.03)."`
- Good: `"Plays the story from a new game, checkpoint by checkpoint."`
- Find: recipe, then judgment on each hit:
  `grep -nA2 'description =' src/program_registry/lib/program_registry.ml | grep -nE 'for now|so far|[0-9]{2}\.[0-9]{2}'`;
  and `git log -p -- src/program_registry/lib/program_registry.ml` for a description edited
  alongside a plan change.

## AGENTS.md hard rules no lint checks yet

Each is stated in `AGENTS.md` (the name below is its bold lead); the auditor runs the recipe and
reads each hit.

- **A1 Programs use only our effect set**: `grep -rnE --include='*.ml' '\b(Unix|Thread|Domain|Eio|Lwt|In_channel|Out_channel)\.' src/games/*/programs src/games/*/actions`.
- **A2 Port the C++ transparently** (each ported module names its source file): `grep -rLE '\.(cpp|h|c)\b|Not in the fork|GamePilot.s own' $(grep -rlE 'fork|upstream|C\+\+' --include='*.mli' src)`; see also R9.
- **A3 Every checkpoint goes through the checkpoint runner**: judgment; `grep -rnE --include='*.ml' 'Effects\.submit' src/bin src/games/*/programs` for programs driving the game outside the runner.
- **A4 Submodules are read-only; maps are read, never copied**: `git -C third_party/<sub> status --short` is empty for each submodule, and `git ls-files src | grep -iE 'maps?/.*\.(json|txt)$'` lists no copied map.
- **A5 Machine-specific paths come from environment variables**: `git grep -nE '/Users/|/home/[a-z]|[A-Z]:\\\\' -- src docs dev run protocol daemon | grep -v /home/example/` (the protocol goldens' `/home/example` is an example).
- **A6 The FireRed ROM, its path and its hash never enter this repo**: `git grep -niE '\.gba\b|sha1.*[0-9a-f]{40}' -- . ':!third_party'`.
- **A7 Swappable parts sit behind one boundary each**: judgment; read new I/O backends, probes,
  handlers and RNG users for a second way in.
