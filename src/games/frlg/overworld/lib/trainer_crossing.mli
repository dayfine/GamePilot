(** A walk leg that crosses the sight of a trainer not beaten yet
    ({!Trainer_sight}), walked a piece at a time: each piece ends on the next
    tile a trainer may see, and the walk then waits for the trainer's "!", walk
    up and text. A text is the trainer's: the battle is fought, the trainer
    counts as beaten, and the walk stops on that tile with the trainer beside
    the player, for the caller to plan the rest round them.

    Ported from the fork's Overworld/PokemonFRLG_OverworldTrainerCrossing and
    the trainer watch of Overworld/PokemonFRLG_OverworldRecoveryWalk, with the
    trainer's stand from Overworld/PokemonFRLG_OverworldReanchor. Where we
    differ: the fork holds the whole leg, watches after it, and finds the player
    again from the stop's timing and the trainers' sight (the tiles the stop may
    have come on, then holds to walls); a trainer who wanders, as Bond Bridge's
    Aroma Lady Nikki, may see the player from more than one tile, so here the
    tile is fixed before any trainer can speak. *)

open Grid_maps

(** What the watch after a step onto a seen tile saw. *)
type sighting =
  | Spoke  (** A text: a trainer saw the player. *)
  | Wild_battle  (** A battle with no text first, set off by the step. *)
  | Nobody  (** Nothing by the end of the watch. *)

type game_steps = {
  walk_piece : seen:bool -> Connected_maps.place Grid_planning.Leg.t -> unit;
      (** Walks a piece from its start to its end; [seen]: it ends on a tile a
          trainer may see, so its text is not pressed through after it. *)
  await_trainer : watch_ms:int -> sighting;
      (** Watches for [watch_ms] for what a trainer's sight sets off. *)
  flee : unit -> unit;
      (** Runs from a wild battle a step set off, back to the overworld. *)
  fight_trainer : unit -> (unit, Pokemon_engine.Failure.cause) result;
      (** Plays the battle of a trainer who spoke, from their text to the
          overworld after it. *)
  log : string -> unit;  (** Where the crossing says what it saw. *)
}
(** What a crossing reads and does in the game. *)

(** How a crossed leg ended. *)
type outcome =
  | Walked  (** On the leg's end, no trainer fought. *)
  | Stopped_by_trainer of {
      world : Frlg_steps.world;
          (** The world with the trainer on the tiles they may have walked up to
              ({!Frlg_steps.with_walked_up}). *)
      at : Connected_maps.place;
          (** Where the trainer stopped the player, facing the leg's way. *)
      fought : Trainer_sight.trainer list;
          (** The trainers who may have seen the player there, now beaten. *)
    }

val crosses :
  Frlg_steps.world ->
  beaten:Trainer_sight.trainer list ->
  Connected_maps.place Grid_planning.Leg.t ->
  bool
(** Whether a walk leg steps onto a tile a trainer not in [beaten] may see
    (after its start, before a warp). *)

val walk :
  game_steps ->
  Frlg_steps.world ->
  beaten:Trainer_sight.trainer list ->
  Connected_maps.place Grid_planning.Leg.t ->
  (outcome, Pokemon_engine.Failure.cause) result
(** Walks the leg in pieces, watching for the trainers not in [beaten]. Fails as
    [fight_trainer] does. *)

val await_on_screen : watch_ms:int -> sighting
(** [await_trainer] on the screen: the white text box, or a battle's screen with
    no box ({!Frlg_readers.Dialog}, {!Frlg_readers.Battle_screen}). *)
