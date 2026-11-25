# E. SV isolated shiny hunts

Goal: shiny-hunt one species at a spot where a type sandwich makes it the only thing that spawns, so
every encounter is the target (one family per hunt).

## Source plan

Research and a prototype on the fork's `agents` branch,
`pokemon_sv/research/isolated-encounters/2026-10-23/` (`ANALYSIS_AND_PLAN.md`, `REPORT.md`,
`STARTER_SURVEY.md`, `KITAKAMI_VIDEO_REVIEW.md`, `IMPLEMENTATION_QUEUE.md`), and the field runs in
`pokemon_sv/runs/isolated-2026-10-24/`.

- **Approach.** Build a catalog of validated spots and reusable movement first, then one spot; no
  general navigation or overworld shiny classifier up front. Spots and type tables were mined from a
  public spawn optimizer, PokeAPI evolution chains and Serebii's fly points (sources and hashes in
  `source_manifest.json`): about 94 families have a type where only they score 100 in some table.
- **First candidates.** Chespin at Chargestone Cavern (reuses the BBQ route) and Charcadet at West
  Province Area One (user priority); Torchic and Cyndaquil next; controls Mareep, Oricorio, Kirlia;
  Larvesta in Asado Desert as a riding loop. Kitakami adds 26 video-derived profiles and a
  "stationary spawn funnel" idea (Sentret's cave).
- **Prototype** (fork PR #39, closed, branch `prototype/sv-isolated-hunt`): rows of species, spot,
  ball and shiny action; save, make the type sandwich, fly and approach, bounded clearing sweeps,
  the shared battle handler (species, shiny, flee or catch).
- **Result** (2026-10-24): only control trials ran (Area Zero platform, no sandwich): clearing at a
  fixed viewpoint did not sustain spawns. **No spot, sandwich or shiny was validated.**

## Mapping onto GamePilot

Slice S3 (stack design section 9): free-camera 3D, so it needs model or audio probes (shiny sparkle
sound, overworld models) that FRLG and BDSP never needed. `src/games/sv`, Switch only.

## Steps

1. Field-validate one spot by hand on the console: anchor, approach, encounter rate with the sandwich,
   reset behaviour. This was the next stage on the fork and is still open.
2. SV readers: map, fly menu, sandwich screens, battle start, shiny (sound or sparkle).
3. Port the sandwich maker and fly-to from PA/CC (upstream has both) as actions.
4. One-spot hunt program, then the catalog as data.

## Open questions

- Which spot first: Charcadet (user priority) or Chespin (easier route)?
- Shiny detection in the overworld vs in battle: the prototype entered battles to check.
