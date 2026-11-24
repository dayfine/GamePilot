# A4. FRLG legendaries

Goal: catch the FireRed legendaries the save can reach, in Luxury Balls, optionally shiny through
Static RNG (A5).

## Source plans

- **Legendary Catch**, fork PR #780 (`Programs/LegendaryCatch/DESIGN.md` on `frlg/legendary-catch-precheck`):
  options per target, a precheck that sums the requirements of all ticked targets (party: OR/MAX of
  levels and speeds; bag: SUM of Luxury Balls and Max Repels, MAX of Leftovers), and the catch loops:
  - Articuno, Zapdos, Moltres: lead Parasect with Spore and False Swipe, then Luxury Balls, Spore
    again on waking.
  - Mewtwo: a Haunter or Gengar Taunts first (blocks Recover and Safeguard), then the Parasect loop.
  - Raikou, Entei, Suicune (roamers): Mean Look, Taunt, Hypnosis from the trapper, then balls. The
    design warns that a roamer which uses Roar is gone from the save.
- **Where and when**, from the fork's story design (`AutoStory-FRLG-FutureEvents.md`, PR #130),
  "Legendaries and extras" and "RNG handoffs": Articuno in Seafoam B4F, Zapdos in the Power Plant,
  Moltres at the Mt. Ember summit (Sevii row 15.03), Mewtwo in Cerulean Cave (after the Sevii story),
  and one roaming beast chosen by the starter (Bulbasaur: Entei, Charmander: Suicune, Squirtle:
  Raikou), released when the Sapphire is given (16.03). Each has an RNG handoff: save facing the
  target, run StaticRng (or RoamingLegendaryRng), resume.

The two disagree on Lugia, Ho-Oh and Deoxys: #780 lists them, the story design marks Navel Rock and
Birth Island **unsupported** because they need event tickets. This plan follows the story design
until the user says the Switch release has the tickets.

## Steps

1. **Precheck** port: the requirement sum as pure OCaml with table tests (the C++ unit test as
   oracle), then party and bag checks on the readers.
2. **Static catch loop** (`src/games/frlg/battle`): the Parasect loop on the scripted battle runner,
   with a foe HP reader to know when False Swipe has done its job, and a sleep check.
3. **One checkpoint per legendary** (`frlg.legendaries`): walk to the target, save facing it, battle
   and catch, check the party, save. Articuno and Zapdos first (no Sevii needed).
4. **Mewtwo and the beast** after A2; the beast needs its own search action (roamer location).
5. **Shiny option**: stop at "saved facing the target" and hand over to A5's Static RNG.

## Prerequisites

A level-100 Parasect with Spore and False Swipe and a Haunter or Gengar with Mean Look, Taunt and
Hypnosis, per #780 (A1's leveling program or A3's ACE can supply them; both are open decisions), Luxury
Balls (A3, or bought), Max Repels.

## Open questions

- Check the movesets in #780 against the decomp's learnsets before building the team around them.
- With Master Balls from A3, is the whole catch loop needed, or only for the shiny RNG path where
  the ball is chosen?
- Mewtwo and the beast: catch normally or RNG? (For Snorlax the user chose no RNG.)
