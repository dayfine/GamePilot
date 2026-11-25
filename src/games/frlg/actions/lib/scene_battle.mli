(** The plan's [battle] event on FireRed: one battle that a talk or a scene has
    started, fought to its end with {!Trainer_battles.script} (the lead's moves
    in slot order). The lines after it are left to the plan's next event, a
    [scene], since a story battle's script goes on: Three Island's Lostelle asks
    for help, her Hypno attacks (a wild battle, a level 30 Hypno, in pokefirered
    data/maps/ThreeIsland_BerryForest/scripts.inc), and once it is over she
    thanks the player, gives a berry and is warped home with them.

    Not in the fork, whose [battle] events carry an opponent and a policy; this
    one reads no args but [may_lose]. *)

val run :
  Trainer_battles.game_steps ->
  may_lose:bool ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** The battle waited for (at once if it is on the screen), then fought. A
    battle lost fails as [battle_lost] unless [may_lose]. The steps' [settle] is
    not run. *)

val play :
  log:(string -> unit) ->
  fight:(Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome) ->
  may_lose:bool ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** {!run} on {!Trainer_battles.live_game_steps}. *)
