(** Trainer battles in a row on FireRed: the plan's [train] event. Each battle
    is waited for through the lines before it, fought with {!script} to its end,
    and the lines after the last one are pressed through to a quiet overworld. A
    scene that chains battles (pokefirered
    ThreeIsland_EventScript_BattleBikersScene: three Biker goons, then Cue Ball
    Paxton, each with their lines before and after) is one [train] event.

    Ported from the fork's Elite Four farmer
    (Programs/Farming/PokemonFRLG_EliteFourFarmer.cpp): [run_battle()] attacks
    at each battle menu and presses through the text until the menu comes back
    or the battle ends, and a fainted attacker is a lost run;
    [clear_post_battle_dialog()] presses B until the trainer's last lines close.
    Where we differ: the move is the first of the lead's slots not out of PP,
    where the farmer picks one per opposing species from its plan; the prompts
    are read and answered ({!Frlg_battle.Event_rule}) where the farmer mashes B;
    and the battles are not walked to, a scene brings each one. *)

type outcome =
  | Won of int  (** this many battles, each to its end *)
  | Lost of { battle : int; why : string }
      (** battle [battle] (from 1) failed: the lead fainted, or the script had
          no answer; the game is left in that battle *)

type game_steps = {
  await_battle : unit -> (unit, Pokemon_checkpoints.Failure.cause) result;
      (** The lines before a battle pressed through until it starts; [Ok] at
          once if one is on the screen. *)
  fight : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
      (** The battle played to its end. *)
  settle : unit -> (unit, Pokemon_checkpoints.Failure.cause) result;
      (** The lines after the last battle pressed through to a quiet overworld.
      *)
  log : string -> unit;
}

val script : Frlg_battle.Battle_script.t
(** Every action menu: the lead's moves in slot order, each until the game
    refuses it for want of PP. No member is sent in, so a fainted lead fails the
    battle (the farmer's [ATTACKER_FAINTED]). Moves to learn are not learned,
    and a trainer's "Will ... change POKéMON?" (the Shift battle style, read by
    {!Switch_offer}) gets NO, as {!Frlg_battle.Scripted_battle} answers every
    {!Frlg_battle.Battle.Switch_offer}. *)

val run :
  game_steps ->
  battles:int ->
  (outcome, Pokemon_checkpoints.Failure.cause) result
(** [battles] battles, then the settle. [Error] when a battle never came (the
    overworld went quiet first) or the settle failed; a battle fought and not
    won is [Ok (Lost _)], for the caller to judge. A battle that leaves the
    screen counts as won: losing one shows the party list first (the lead
    fainted, members left), which fails the script. A whiteout with no member
    left would count as won; the checkpoint's money and position catch it. *)

val failure : outcome -> (unit, Pokemon_checkpoints.Failure.cause) result
(** [Won] passes; [Lost] fails as [battle_lost], naming the battle and why. *)

val live_game_steps :
  log:(string -> unit) ->
  fight:(Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome) ->
  game_steps
(** The settles on the screen ({!Scene_looks}), and [fight] for the battle. *)

val play :
  log:(string -> unit) ->
  fight:(Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome) ->
  battles:int ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** {!run} on {!live_game_steps}, judged by {!failure}. *)
