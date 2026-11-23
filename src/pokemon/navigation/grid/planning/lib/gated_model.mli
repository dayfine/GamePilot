(** A game's step model over maps with gates ({!Map_gates}), wrapped for the leg
    planner: the search state is the game's state and the gate state.

    - A closed gate is a wall (the game's model reads tiles with
      {!Gate_tiles.resolved_tile}), so a route goes round it.
    - A closed Card Key gate the player faces can be opened (an {!Open_gate}
      leg: face it, press A) if the Card Key is held; the state after the leg
      has it open, and the route may go through.
    - A statue faced from its tile can be pressed (a {!Press_switch} leg), which
      flips its switch, so every gate that follows it changes with it, on every
      floor. A route may flip it, and flip it back.

    One-way warps are the game's to take as any warp: the model leads the player
    to the warp's arrival, and the maps give no way back from it, so a route
    takes it forward only. *)

type 'inner state = { inner : 'inner; gates : Gate_state.t }
(** The game's state and the gate state. *)

type Leg.action +=
  | Open_gate  (** Face a closed Card Key gate and press A. *)
  | Press_switch  (** Face a statue and press A. *)

type rules = {
  card_key_held : bool;
      (** The player holds the Card Key: a plan may open Card Key gates. *)
  open_gate_cost : int;
      (** Cost of opening a gate, on top of {!Leg_costs.t.per_tile}: the dialog.
      *)
  press_switch_cost : int;  (** The same for a statue: its dialog and yes/no. *)
}

val default_rules : rules
(** No Card Key; opening a gate costs 10, pressing a statue 20. *)

type 'inner game = {
  compare_inner : 'inner -> 'inner -> int;
  press : 'inner -> Direction.t -> Gate_state.t -> 'inner Leg.step option;
  held_at : 'inner -> Direction.t -> Gate_state.t -> bool;
  place_of : 'inner -> Connected_maps.place;  (** Where the player is. *)
  open_stop_risk : ('inner -> Direction.t -> Gate_state.t -> int) option;
  tap_stop_risk : ('inner -> Direction.t -> Gate_state.t -> int option) option;
  open_check_risk :
    ('inner ->
    Direction.t ->
    run:int ->
    next:Direction.t option ->
    Gate_state.t ->
    int)
    option;
}
(** The game's step model as {!Step_model.t}, each function also taking the gate
    state the step is made in. *)

val simple_game :
  compare_inner:('inner -> 'inner -> int) ->
  press:('inner -> Direction.t -> Gate_state.t -> 'inner Leg.step option) ->
  held_at:('inner -> Direction.t -> Gate_state.t -> bool) ->
  place_of:('inner -> Connected_maps.place) ->
  'inner game
(** A game that weighs no risks of its own. *)

val model :
  'inner game -> Connected_maps.t -> rules -> 'inner state Step_model.t
(** The wrapped model. A press the game allows is the game's step with the gate
    state carried along; one it refuses may open a gate or press a statue. *)
