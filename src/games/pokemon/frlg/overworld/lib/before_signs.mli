(** Where a leg held into a sign stops: FireRed reads a sign faced going north
    or south at every press, so a leg whose hold is interrupted at once, hold
    after hold, may stand before one the plan did not walk into. Ported from the
    fork's [before_signs()] (Overworld/PokemonFRLG_OverworldHeldInPlace). *)

open Grid_maps

val open_leg_shortfall : int
(** 2: the most tiles an open leg was seen to end short of, or past, its end
    with nothing on screen (the fork's [OPEN_LEG_SHORTFALL]). *)

val possible_starts :
  before:Connected_maps.place Grid_planning.Leg.t option ->
  Connected_maps.place Grid_planning.Leg.t ->
  Connected_maps.place list
(** Where the leg may have started: its planned start and, when the leg [before]
    it was an open walk on the same map, up to {!open_leg_shortfall} tiles short
    of or past that leg's end. *)

val stops :
  Frlg_steps.world ->
  Connected_maps.place list ->
  Connected_maps.place Grid_planning.Leg.t ->
  Connected_maps.place list
(** From each start, where holding the leg's direction for its tiles and
    {!open_leg_shortfall} more stops with a sign ahead; distinct, in the starts'
    order. Empty when no sign on the maps is ahead of any. *)
