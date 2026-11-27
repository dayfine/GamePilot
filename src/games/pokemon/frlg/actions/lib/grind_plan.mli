(** A ["grind"] game action as data: whom to level and what it must learn (the
    {!goal}), and the named {!strategy} it is levelled with, read from
    [src/games/pokemon/frlg/assets/grind_strategies.json]. Pure: {!Grind} runs
    it.

    A strategy is where to stand, who leads each battle, and how and how often
    to heal. Only the switch trick is written: the grinder leads, switches to
    the sweeper on turn 1, and both share the EXP. Fighting alone when the
    grinder surely wins needs readers FireRed lacks (the foe's species, the
    grinder's level). *)

type lead =
  | Switch_to_sweeper
      (** the grinder leads and switches to the sweeper on turn 1 *)

type heal =
  | Nurse of Pokemon_engine.Pose.grid
      (** talk to the nurse from this tile (walked to and back) *)
  | Pad of Pokemon_engine.Pose.grid  (** step on this healing tile and back *)

type strategy = {
  name : string;
  spot : Pokemon_engine.Pose.grid;  (** the grass tile battles are paced from *)
  pace : Grid_geometry.Direction.t;
      (** the way paced, one step and back: the tile that way is grass too
          ({!Pacing}) *)
  lead : lead;
  heal : heal;
  heal_every : int;
      (** battles between heals: FireRed has no HP or PP reader, so the sim's
          heal rate stands in for "the sweeper is low" *)
}

type goal = {
  species : string;  (** the grinder, a slug *)
  target_level : int;
      (** the level the move comes at: the grind ends once the grinder's level,
          read after each battle, reaches it *)
  learn_move : string;  (** a slug; the goal is met once the grinder knows it *)
  learn_slot : int;  (** the move (0-3) it replaces *)
}

type t = {
  goal : goal;
  strategy : strategy;
  sweeper : string;  (** the member that fights, a slug *)
  sweeper_moves : int list;
      (** its move slots (0-3), the next one taken when one runs dry *)
  max_battles : int;  (** more battles than this fail the action *)
  round : bool;
      (** one round only ({!Grind.run}): from the heal place to the spot, at
          most [heal_every] battles, and back to heal *)
}

val default_strategy : string
(** ["victory_road_2f"]. *)

val strategies_of_json : Yojson.Safe.t -> (strategy list, string) result

val load_strategies : unit -> (strategy list, string) result
(** The asset, found from the working directory and read once. *)

val decode :
  strategy list -> Json_field.obj -> (t, Pokemon_engine.Failure.cause) result
(** The action's args: ["species"], ["target_level"], ["learn_move"],
    ["learn_slot"] (from 1), ["sweeper"], ["sweeper_moves"] (from 1),
    ["max_battles"], ["strategy"] (default {!default_strategy}) and ["round"]
    (default [false]). [bad_args] naming the field. *)

val apply_options : Run_options.t -> t -> t
(** Applies [--options sweeper=SPECIES] over the plan's sweeper when given. *)

val met : goal -> known:string list -> bool
(** The grinder knows the move. *)

val heal_due : strategy -> since_heal:int -> bool
(** [heal_every] battles since the last heal. *)

val battle_script : t -> Frlg_battle.Battle_script.t
(** The lead's opening (switch to party slot 1, the sweeper's place), the
    sweeper's moves after it (and sent in, should the grinder faint first), YES
    to the goal's move only (into its slot), NO to any other. *)

val describe : t -> string
(** One line for the log. *)
