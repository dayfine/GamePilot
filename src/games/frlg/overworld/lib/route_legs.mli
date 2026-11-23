(** A planned leg as the walker walks it: the hold ({!Grid_walker.Leg_spec.t})
    with FireRed's tile times, or a turn on the spot. Ported from the fork's
    Overworld/PokemonFRLG_OverworldWalk ([leg_spec()], [tile_time()],
    [turns_first()]). Pure. *)

open Grid_maps

type gait =
  | Walking
  | Running  (** B held, once the player has the Running Shoes. *)

(** What the walker does for a leg. *)
type move =
  | Hold of {
      spec : Grid_walker.Leg_spec.t;
      running : bool;  (** B is held with the D-pad. *)
      warps : bool;  (** The last step takes a warp: its fade follows. *)
      wild : bool;  (** A wild battle may stop it. *)
      turn_first : bool;
          (** A turn tap first: the player faces another way, and the leg does
              not start on an exit mat its way (whose first press warps). *)
    }
  | Turn of Direction.t

val move_of :
  Frlg_steps.world ->
  gait ->
  facing:Direction.t option ->
  Connected_maps.place Grid_planning.Leg.t ->
  (move, string) result
(** The leg's move from a player facing [facing]; an error for an action leg
    (Surf, a gate), which the walker does not do yet. A ledge hop takes two
    tiles' time; each step onto a connected map is a stalled step. Indoors,
    where the game does not let the player run, the leg walks. *)

val mover : running:bool -> Direction.t -> int -> Wire.command list
(** The D-pad held for the time, with B when running, then the release. *)

val turn_tap : Direction.t -> Wire.command list
(** A tap that turns the player without a step, and the wait for the turn. *)
