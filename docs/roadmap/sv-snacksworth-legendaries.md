# F. SV Snacksworth legendaries

Goal: with Snacksworth's treats already in the bag, build a catching team, fly to each of the 25
returning legendaries (The Indigo Disk), catch it and save, in Scarlet or Violet, with no manual
step after the declared start. Earning the treats (BBQ) is out of scope.

## Source plan

PokemonSimulation draft PR #78 (branch `sv-snacksworth-automation-plan`): `docs/sv/snacksworth-plan.md`
(team, battle profiles, recovery, order) and `docs/sv/snacksworth-routes.md` (team acquisition and a
flight anchor plus final landmark for each target, with sources). It is researched, not console
validated: no route, timing or battle has been run. This page is the short version; the details
and sources stay in those two files.

**Start state.** Both DLC regions and the post-game open, free flight, full obedience. Not assumed:
a trained team, money, candies, TMs, shards, stones, or every flight point registered; the program
audits them first. All 25 targets are Lv 70 except Kubfu (Lv 30).

## Catching team

| Helper | Moves | Notes |
|---|---|---|
| Golduck | Soak, Taunt (optional Chilling Water, Amnesia) | Soak makes the target pure Water, so False Swipe hits Ghosts and Thunder Wave hits Ground types |
| Gallade | False Swipe, Thunder Wave, Taunt, Swords Dance | Ghost Tera (50 Ghost shards at Medali's Treasure Eatery) for the horses |
| Clefable | Skill Swap (optional Reflect, Light Screen, Moonlight) | Magic Guard required (Ability Capsule if Cute Charm); swapped onto targets that take recoil or sand |

All Lv 100, above the Lv 70 one-hit-KO users. Acquisition: Golduck and Gallade in North Province
Area One (or male Kirlia plus the Medali ruins Dawn Stone), Clefairy at night around Crystal Pool in
Kitakami (TM098 Skill Swap is picked up there), Moon Stone by the Porto Marinada lighthouse. Moves
from Remember Moves, held TMs, or crafting.

## Battle profiles

- **Ordinary**: save outside interaction range; Soak; Taunt early on healers and setup users; Skill
  Swap Magic Guard onto the target if recoil or weather needs it; Thunder Wave until paralysis is
  confirmed; False Swipe until a conservative HP model guarantees 1 HP (a red bar is not proof);
  balls by policy (Ultra, then Timer); confirm the catch, then save. Reset to the pre-battle save on
  a KO, an unexpected state, or unsafe PP or stock.
- **Solgaleo**: Magic Guard before low HP (recoil); watch Metal Burst against the catcher.
- **Glastrier, Spectrier**: Ghost-Tera Gallade as the final catcher (Thrash and Double-Edge cannot
  hit it); Soak Spectrier first; clear confusion before weakening; Taunt against Iron Defense and
  Disable.
- **Exceptions table** in the plan: Kubfu (no chip damage), Lugia and Ho-Oh (Recover, Pressure),
  Groudon and Rayquaza (Rest), Kyogre (Aqua Ring), Latias (Reflect Type undoes Soak), Moltres (sand).

## Routes

Each target starts from a registered flight point and ends at a visually verified interaction spot
(e.g. Kubfu: Fury Falls, by the sign; Zapdos: top of the Poco Path lighthouse; Groudon: the cave under
Alfornada, which needs ledge waypoints). Unregistered anchors (Gracia Stones, Groundblight Shrine)
get a registration route first. The full table of 25 is in `snacksworth-routes.md`.

## Mapping onto GamePilot

Slice S3: `src/games/sv`, Switch only, free-camera 3D. Pieces shared with E (SV isolated hunts):
fly-to with a north-up map, mount and camera reset, battle start and shiny readers. New here:
a battle state machine with confirmed status, type and ability changes (Soak, paralysis, Skill Swap,
Tera), an opponent HP model for False Swipe, a ball policy, a per-target progress file (caught,
route revision, last save), and altitude-aware route data per target as plans.

## Order (from the plan)

1. Preparation pilot: catch the three helpers, verify moves, ability, evolution, Ghost Tera.
2. First complete catch: Kubfu at Fury Falls (fly, approach, battle, catch, save, resume).
3. A simple Lv 70 target, then an Electric one (Zapdos) and a Ghost one: Soak and Thunder Wave.
4. Special battles: healers, sand, Solgaleo, both horses, worst cases checked before unattended runs.
5. All routes, recorded with real controller timings (never from a written guide).
6. Resume and endurance on both versions; report real trial counts.

## Open questions (from the plan)

- Gallade: a bounded daytime search, or male Kirlia plus a Dawn Stone?
- How much EXP, money, shards and TM material the save already has versus farming needed.
- Reliable capture and save detectors, opponent PP bounds, the final ball policy.
