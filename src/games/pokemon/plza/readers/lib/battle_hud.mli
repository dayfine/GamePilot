(** Reader: the battle HUD is up, the fork's battle-started event
    (PokemonLZA_AutoStoryScreenEvents.cpp): the A of ["X A: Select Move"] at the
    bottom centre (a {!Interact_prompt} match in the box 0.40, 0.84, 0.20,
    0.10), or the lead's panel with the stat markers or the trainer's Poké Balls
    (PokemonLZA_BattleHudDetectors.cpp, every box and bound as the fork measures
    it on 1080p):

    - the panel: the level badge (x 240-320, y 799-818) dim cyan over half its
      pixels, and the HP bar (x 236-440, y 882-902) 80% bar pixels, either fill
      (channels 90 or more apart) or grey trough (channels within 25, mean 60 to
      140);
    - the markers: of five 16 x 12 slots at x 405-513 (27 apart), y 800, one
      over 20% the triangle's blue (red 70 or less, green 150 to 210, blue 225
      or more) and three or more under 5% blue and 6 to 50% white (every channel
      over 200, within 30 of each other);
    - the trainer's balls: of six 14-pixel slots from x 857.5 (centres, 41
      apart), one whose top (y 60-66) is 40% coral red (red over 190, over green
      by 70, over blue by 60) and bottom (y 72-80) 40% white (channels over 200,
      within 40).

    The fork counts the HP bar's fill and trough with one test; the line-share
    probes take only "and"s of linear comparisons, so the bar is seven probes
    whose pixels do not overlap (one per strongest and weakest channel, and the
    trough), their shares summed. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** Every probe {!shown} needs. *)

val hint_shown : Effects.measurements -> bool
(** The battle hint's A. *)

val panel_shown : Effects.measurements -> bool
(** The lead's panel: the level badge and the HP bar. *)

val markers_shown : Effects.measurements -> bool
(** The stat markers: one slot with the triangle and three or more empty. *)

val trainer_balls_shown : Effects.measurements -> bool
(** The trainer's Poké Balls: one slot with a ball. *)

val lead_hp : Effects.measurements -> float option
(** The lead's HP: the share of the HP bar's box in the fill colours (the
    panel's six fill probes, the trough left out), while the level badge shows;
    [None] without the badge. The box covers the left 204 of the bar's about 288
    pixels, and the HP text over its bottom rows, so a full bar and any HP over
    about 70% read 0.89; 1 HP of 19 reads 0.04 (01.03, console B), as a fainting
    lead's bar does. The trough is not needed: at 640 x 360 it reads darker than
    the fork's grey. Ours: the fork reads no HP in a story battle. *)

val shown : Effects.measurements -> bool
(** The hint, or the panel with the markers or the trainer's balls. *)
