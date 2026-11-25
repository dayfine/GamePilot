# Dex Collection (FRLG)

Registry id `frlg.dex_collection`, group FRLG / Pokedex (`src/program_registry`). It catches wild
Pokemon the Pokedex has not caught yet, the first usable slice of the collector in
`docs/roadmap/frlg-dex-exclusives.md` (issue #15, step 5): land wild catches, non-shiny, toward the
60 caught the National Pokedex needs (Sevii checkpoint 07, `docs/roadmap/frlg-sevii-islands.md`).
It runs on mGBA.

| Checkpoint | Content |
|---|---|
| 01-ultra-balls | From Route 10's Pokemon Center: fly to Indigo Plateau, 10 Ultra Balls at its Center's counter ($12,000), fly back, heal |
| 02-route10-new-species | The Pokedex count off the Trainer Card; Route 10's north grass: catch 2 species without the caught mark, run from the rest; back to the nurse; the count again |
| 03-copy-candies-and-balls | At Route 10's nurse: MIMIEN to slot 1, the Mail Glitch copies 40 Rare Candies and 40 Ultra Balls (80 Retro Mail) |
| 04-candy-evolutions | At the nurse: candies evolve Pidgey to Pidgeotto and Pidgeot, Rattata to Raticate, Oddish to Gloom (4 species); Blastoise to slot 1 again |
| 05-victory-road-first | Fly to Indigo Plateau, down Route 23 into Victory Road 2F: 3 new species; back to Indigo's nurse |
| 06-retro-mail | Fly to Celadon: 110 Retro Mail at the Dept. Store's 4F; back to Indigo's nurse |
| 07-copy-candies-and-balls | At Indigo's nurse: the Mail Glitch copies 40 more Rare Candies and 90 more Ultra Balls (Victory Road takes about 7 a catch) |
| 08-victory-road-rest | A round from Indigo's nurse: 2 more Victory Road species a round, until the count holds the nine |
| 09-viridian-forest | Fly to Pewter: Farfetch'd and Raticate to the PC, then Viridian Forest's Caterpie, Weedle, Kakuna, Metapod, Pikachu; candies evolve the two that joined; Pewter's nurse |
| 10-route3-east-grass | Fly to Route 4, Route 3's east grass: 3 of Nidoran (male), Mankey, Jigglypuff, Nidoran (female); Route 4's nurse |
| 11-route8-grass | Fly to Lavender, cut into Route 8's grass: Meowth, Growlithe; Lavender's nurse |
| 12-power-plant | Fly to Route 10, surf to the Power Plant: Magnemite, Magneton, Electabuzz; Route 10's nurse |
| 13-mansion | Fly to Cinnabar, Pokemon Mansion 1F: Koffing, Grimer, Weezing; fly back to Route 10's nurse |
| 14-route10-river | Surf on Route 10's river: Tentacool |
| 15-vermilion-routes | Fly to Vermilion: Drowzee in Route 11's grass, Psyduck on Route 6's pond; Vermilion's nurse |
| 16-magikarp-salesman | Fly to Route 4: MIMIEN to the PC, the salesman's Magikarp ($500, once per save), candies to Gyarados; Route 4's nurse |
| 17-eevee | Fly to Celadon: the Eevee on the Condominiums' roof (once per save); fly to Route 10's nurse |
| 18-fuchsia-routes | Fly to Fuchsia: Venonat and Ditto on Route 15, Doduo and Fearow on Route 18; fly to Route 10's nurse |
| 19-pokemon-tower | Fly to Lavender: Gastly and Cubone on Pokemon Tower 3F; Lavender's nurse |

Each starts and ends at a Pokemon Center's nurse, the next one's start, so a save anywhere in Kanto
flies to Route 10's first. A catch
checkpoint tells a new species by the Poke Ball FireRed draws on a wild foe's HP box when its species
is caught (`Frlg_readers.Caught_mark`), so it never opens the Pokedex, and reads the count of
species caught off the Trainer Card (`read_caught`). Catches go to the PC when the party is full.

On the Mail Glitch save (10 caught; Spearow among them), 02 catches Voltorb and Ekans: 12 caught.

Next:

- More routes, one checkpoint each from a Center with its map in PokemonSimulation: Route 24 and
  25 from Cerulean (Weedle, Caterpie, Kakuna, Metapod; Cerulean's two wandering NPCs need a
  route around them), Route 8 from Lavender (Meowth, Growlithe, Ekans; behind Cut trees), Routes
  12 to 15 (Venonat, Gloom, Ditto, Pidgeotto). Celadon's Center has no map yet.
- A `caught` postcondition and precondition (the Trainer Card's count), so Sevii 07 can require 60,
  and a repeat round that runs until it holds.
- The Pokedex list reader and navigation, the catalog and the planner of the roadmap's collector.
