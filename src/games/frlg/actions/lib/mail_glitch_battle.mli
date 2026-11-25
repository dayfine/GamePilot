(** The ["mail_glitch_double_battle"] game action: Lea & Jed's double battle on
    Route 16 that turns the Mail Glitch on (mg-05). Ported from the fork's
    [run_mail_glitch_double_battle_step()], [let_berry_holder_eat()],
    [execute_double_battle_setup_turns()], [restored_single_digit_pp()] and
    [sweep_double_battle()]
    (Programs/MailGlitch/PokemonFRLG_MailGlitchBattle.cpp, the version that
    passed on mGBA, 2026-11-23). The party is CH'DING (Knock Off) in slot 1, the
    sweeper (Blastoise, holding a Leppa Berry, its depleted move at 0 PP) in
    slot 2 and MIMIEN (Recycle, holding Retro Mail) in slot 3.

    One step into Lea's sightline starts the battle. Then, one command per
    action menu, as the fork:
    - turn 0: CH'DING Sand-Attack and the sweeper Bite, on the foe the target
      cursor starts on; the Leppa Berry restores the depleted move at the end of
      the turn;
    - turn 1: CH'DING Knock Off on its ally; at the sweeper's menu the depleted
      move must show PP again, then the sweeper switches out for MIMIEN (party
      slot 2 in battle order), so Knock Off takes MIMIEN's Retro Mail;
    - turn 2: CH'DING switches out for the sweeper (slot 2 again, the battle
      order having changed), MIMIEN uses Recycle, which brings back the eaten
      Leppa Berry over the mail;
    - then {!sweep_menus} menus alternate Surf (the sweeper's, on the left) and
      Recycle (MIMIEN's) until the battle is over.

    Where it differs:
    - The fork reads the three members' species and moves on their summaries;
      here the species come from the reckoned party ({!Party_roster}) and only
      the moves are read. The fork also checks the depleted move shows 0 PP
      before the battle; with no PP digit reader that check is left out.
    - The fork reads the depleted move's PP digits after the Berry turn and
      wants its full PP; here the move menu's PP must not be red (the
      {!Frlg_readers.Move_pp} reader), which says the Berry restored some PP.
    - Knock Off's target is reached with RIGHT ({!Frlg_battle.Battle_cursor}),
      where the fork presses DOWN: pokefirered's target cursor takes both the
      same way. *)

type plan = {
  knock_off_species : string;
  recycle_species : string;
  sweeper : string;
  depleted_move : string;
  step_direction : Grid_maps.Direction.t;
}

val decode :
  Grid_maps.Json_field.obj -> (plan, Checkpoints.Failure.cause) result
(** Args ["knock_off_species"], ["recycle_species"], ["sweeper"],
    ["depleted_move"] (slugs) and ["step_direction"]. *)

type slots = {
  knock_off : int;
  sand_attack : int;
  surf : int;
  bite : int;
  depleted : int;
  recycle : int;
}
(** Move slots (0-3), as the move menu shows them. *)

val find_slots :
  lead:string list ->
  holder:string list ->
  recycler:string list ->
  depleted_move:string ->
  (slots, string) result
(** The slots of the moves the battle uses, from each member's known moves; the
    error names the first move missing. *)

val sweep_menus : int
(** 20: the fork's sweep turn limit. *)

val script : slots -> Frlg_battle.Battle_script.t
(** The battle's commands in order, the sweep included; an action menu past them
    fails the battle, and so does a member fainting. *)

val check_before_first_switch :
  (unit -> bool) ->
  Frlg_battle.Battle.game_steps ->
  Frlg_battle.Battle.game_steps
(** The battle's game steps, with the check run before its first switch (the
    sweeper's, turn 1); a check that fails stops the action as
    [double_battle_berry_not_consumed]. *)

val pp_restored : slot:int -> unit -> bool
(** From the action menu: FIGHT, the cursor to [slot], the move menu's PP read
    not red, then B back to the action menu. *)

val step_into_sight : log:(string -> unit) -> Grid_maps.Direction.t -> unit
(** One step tap ([STEP_TAP], 66 ms, then 700 ms; the fork's
    Overworld/PokemonFRLG_MovementStepPresses.h), the trainers' text pressed
    through until their battle shows. Fails as [double_battle_not_started]. *)

type game_steps = {
  species_at : int -> string option;  (** the reckoned party, slots from 1 *)
  known_moves : slot:int -> string list;  (** read on the summary *)
  start_battle : Grid_maps.Direction.t -> unit;
  restored : slot:int -> unit -> bool;  (** {!pp_restored} live *)
  battle :
    (Frlg_battle.Battle.game_steps -> Frlg_battle.Battle.game_steps) ->
    Frlg_battle.Battle_script.t ->
    Frlg_battle.Scripted_battle.outcome;
      (** the battle played on the battle's game steps as the function changes
          it *)
  after_battle : unit -> unit;  (** back to a quiet overworld *)
  log : string -> unit;
}

val live_game_steps :
  log:(string -> unit) ->
  species_at:(int -> string option) ->
  known_moves:(slot:int -> string list) ->
  battle:
    ((Frlg_battle.Battle.game_steps -> Frlg_battle.Battle.game_steps) ->
    Frlg_battle.Battle_script.t ->
    Frlg_battle.Scripted_battle.outcome) ->
  game_steps
(** The game's game steps: {!step_into_sight}, {!pp_restored}, and the talk
    settle after the battle. *)

val run : game_steps -> plan -> unit
(** Fails as [double_battle_wrong_party], [double_battle_missing_move],
    [double_battle_not_started], [double_battle_berry_not_consumed] or
    [double_battle_failed] (with the battle's reason). *)
