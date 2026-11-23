(** A checkpoint plan ([pokesim-authored-checkpoint/1], owned by
    PokemonSimulation): the stretch of story between two saves, as a list of
    events. Types only; {!Plan_decode} reads them from a plan file.

    Each built-in kind's args are typed here, with the format's fallbacks filled
    in. A [game_action]'s args stay JSON: the game that names the action reads
    them. *)

type leg = { direction : Grid_maps.Direction.t; tiles : int }
(** A straight walk of [tiles] tiles. *)

type item = { item : string; quantity : int }

type route = { target : Pose.grid; fight_wild : bool }
(** A planned walk to [target]; [fight_wild] fights wild encounters on the way
    instead of running. *)

(** What an event does, with its args. *)
type kind =
  | New_game
  | Options
  | Route of route
  | Ready of Pose.grid  (** Walk to the pose and stand ready there. *)
  | Legs of { legs : leg list; fight_wild : bool }
      (** Walk these legs as written, without planning. *)
  | Step of Grid_maps.Direction.t  (** One step or turn toward the direction. *)
  | Talk
  | Answer of bool  (** Answer a yes/no prompt: [true] for yes. *)
  | Scene  (** Clear dialog and cutscenes back to free control. *)
  | Battle of { may_lose : bool }
  | Train of int  (** Fight this many trainer battles. *)
  | Heal
  | Shop of item list
  | Save
  | Game_action of Grid_maps.Json_field.obj
      (** The game's own action, named by the event's [action], with its args.
      *)

type event = {
  id : string;  (** Unique within the checkpoint. *)
  kind : kind;
  action : string option;
      (** The plan's [action]: which of its kind's ways the event takes (["run"]
          for a route), or the game action's name; [None] for the kind's
          default. Always set for a {!Game_action}. *)
  why : string;  (** What the event is for, in the plan author's words. *)
  skip_if : string list;
      (** Flags (named by the game) under which the event is skipped. *)
  declared_after : Pose.declared option;
      (** Where the event leaves the player, as the plan declares it. *)
  once_per_save : bool;
      (** The event spends something the save keeps (money, a TM): the game runs
          it once per save. *)
}

type checkpoint = {
  checkpoint_id : string;
  title : string;
  start : Pose.declared option;
  events : event list;
}

type t = {
  game : string;  (** The plan's [game], e.g. ["frlg"]. *)
  checkpoint : checkpoint;
  execution : Grid_maps.Json_field.obj;
      (** How the game runs the checkpoint (save menu, supplies, ...): its
          fields are each game's own. *)
  metadata : Grid_maps.Json_field.obj option;
      (** The plan's phase, verification and postconditions, kept as written. *)
}
