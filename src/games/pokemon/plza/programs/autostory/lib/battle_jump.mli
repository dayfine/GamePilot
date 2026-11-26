(** A battle that starts before its story battle event: the run goes on at that
    event. Ported from the fork's jump to the story battle
    (Pokemon_StoryEngine.cpp, PokemonLZA_AutoStoryActionTable.cpp and
    PokemonLZA_AutoStorySceneMachine.cpp, on its plza/lean branch, fork PRs 710
    and 725): with a [story_battle] event later in the checkpoint, a walk
    ({!Plza_walk.Walk}) or a scene ({!Plza_story.Scene_machine}, but for a
    battle's start) that sees the battle HUD fails [battle_on_screen], and the
    run jumps to the next [story_battle], skipping the events between. Logged as
    the fork logs it:
    ["[Event] 04-starter-and-andi: battle on screen during approach_starter:
     jumping to andi_battle, skipping andi_battle_start"].

    Where it differs: the engine's runner has no jump, so the stopped event
    passes and each skipped event passes at once with no input (the runner logs
    them started and done); the fork logs the event failed and the skipped
    events not at all. *)

type t
(** One checkpoint run's jump: none yet, or to the battle's event. *)

val make : Plza_engine.Plan.checkpoint -> log:(string -> unit) -> t
(** No jump yet, over the checkpoint's events. *)

val battle_ahead : t -> Plza_engine.Plan.event -> bool
(** A [story_battle] event comes after this one. *)

val after :
  t ->
  Plza_engine.Plan.event ->
  (unit, Engine_run.Failure.cause) result ->
  (unit, Engine_run.Failure.cause) result
(** An event's outcome, as the run takes it: [battle_on_screen] with a battle
    ahead jumps there (logged) and passes; any other outcome is the event's. *)

val run :
  t ->
  Plza_engine.Plan.event ->
  (unit -> (unit, Engine_run.Failure.cause) result) ->
  (unit, Engine_run.Failure.cause) result
(** Runs the event, or, during a jump, passes it at once until the battle's
    event; that one (or any after it, should the battle's [skip_if] skip it)
    runs and ends the jump. *)
