(** The ["prepare_berry_pp"] game action: use up a lead's move in wild battles,
    so that a Leppa Berry held later restores the move's PP at the end of a
    battle's first turn (mg-05a, Blastoise's Blizzard). Ported from the fork's
    [run_prepare_berry_pp_step()] and [drain_pp_in_wild_battle()]
    (Programs/MailGlitch/PokemonFRLG_MailGlitchBattle.cpp, the Route 16 version
    that passed on mGBA, 2026-11-23): the lead must be [species]; each wild
    battle is found by turning in place ({!Spin_for_encounter}) and fought with
    [move] while it has PP, then with [backup_move].

    Where it differs, for want of readers:
    - The fork finds each battle by turning in place ([spin_for_encounter()]),
      reading the player's facing before each batch so no turn tap is a step.
      With no facing reader, turning here stepped the player off the grass
      (mg-05a testing 1: from Route 8 (45, 12) onto the path at (46, 12), then
      no battle in 25 batches). The battles are paced for instead, one step
      [pace] and back on grass tiles ({!Pacing}, the fork's capture method).
    - The fork reads the move's PP off the summary and counts it down, stopping
      after the battle its last PP goes in. With no PP digit reader here the
      move is used until the game refuses it ("There's no PP left for this
      move!", {!Frlg_battle.Battle.Refused}) and the loop stops after that
      battle: one battle more than the fork when the last PP went on a battle's
      last turn.
    - The fork checks each foe for a shiny, uses a Super Potion when the lead's
      HP bar is under 80% and stops when the lead is poisoned. There is no
      shiny, HP or status reader here, so none of the three is done.
    - The fork's closing turn to the event's declared facing is left out (no
      facing reader): mg-05a's next event is a Fly. *)

type plan = {
  species : string;
  move : string;
  backup_move : string;
  pace : Grid_geometry.Direction.t;
      (** The way the battles are paced for: one step from the start tile and
          back ({!Pacing}). *)
}

val decode : Json_field.obj -> (plan, Pokemon_engine.Failure.cause) result
(** Args ["species"], ["move"] and ["backup_move"] (slugs), and ["pace"] (a
    direction). *)

val script : move_slot:int -> backup_slot:int -> Frlg_battle.Battle_script.t
(** A wild battle: [move_slot] until the game refuses it, then [backup_slot]. *)

val max_battles : int
(** 64: a move's PP is at most 64 (PP Max on a 40 PP move) and every battle uses
    at least one. *)

type game_steps = {
  lead : unit -> string option;  (** the species in party slot 1 *)
  known_moves : slot:int -> string list;  (** read on the summary *)
  find_battle : unit -> unit;  (** paced until a wild battle *)
  battle : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
  log : string -> unit;
}
(** The steps that press, so the loop runs on a fake in tests. Each raises
    {!Menu_input.Action_failed} when it fails. *)

val run : game_steps -> plan -> unit
(** Fails as [berry_pp_wrong_lead], [berry_pp_missing_move],
    [berry_pp_battle_failed] or [berry_pp_out_of_battles]. *)
