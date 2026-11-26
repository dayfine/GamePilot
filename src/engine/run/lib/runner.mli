(** Runs a checkpoint's events in order through a game's handlers
    ({!Game.Make.t}).

    Before any event runs, every game action the checkpoint names must have a
    handler. Then, when the plan's [end.is] names flags and every one holds
    already ({!Game.Make.t}'s [flag_holds]), no event runs: each is reported
    skipped,
    ["[Story] <checkpoint>: already at its end (<flags>): passed, no event run"]
    is logged, and the checkpoint passes without its end checks (nothing was
    pressed, so a promised change from the start cannot hold). Otherwise, per
    event: it is skipped when a flag its [skip_if] names holds; otherwise its
    handler runs, and once it passes, the game's position (when it can tell)
    must match its [declared_after] ({!Engine_rules.POSE.matches}). The first
    event that fails stops the run. Each event's start (with its [why]), skip,
    end and failure is logged as ["[Story] <checkpoint> #<n> <event>: ..."]. A
    handler that raises is logged as failed and the exception passes through.

    The runner prints none of the game's rules: it says each line as a
    {!Log_line.Make.t}, poses and failures kept as values, and the engine prints
    it through the game's text ([Program_engine.Make]'s [Runner], which keeps
    this module's lines as they read).

    An event's [once_per_save] is the game's to honour in its handler: only the
    game knows what its save already holds. The runner neither saves nor
    reloads: the caller (or {!Repeat_until}) decides that. *)

open Engine_plan

(** The runner over the game's rules. *)
module Make (T : Engine_rules.GAME_RULES) (Raw : Plan.RAW) : sig
  val run :
    ?end_at:T.Pose.t ->
    ?end_state:
      T.Postconditions.t * (T.Postconditions.t -> T.Postconditions.reads) ->
    ?on_event:(int -> Log_line.Make(T).t Event_progress.t -> unit) ->
    ?events:Event_range.t ->
    say:(Log_line.Make(T).t -> unit) ->
    Game.Make(T)(Raw).t ->
    Plan.Make(T)(Raw).checkpoint ->
    (unit, Failure.Make(T).t) result
  (** With [end_at] (the checkpoint's declared end), after the last event the
      player must read there, or the run fails with {!Failure.Make.Not_at_end}
      (also when the game cannot tell where they are), logged as
      ["[Story] <checkpoint> end <pose>: holds"] or [": failed: ..."]. The C++
      end check, of the map and tile, is in
      [Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.cpp] on the fork's
      [frlg/lean].

      Once the end position holds, every flag of the plan's [end.is] must hold;
      each is judged as a promise and logged as
      ["[End] <checkpoint> <flag>: passed: holds"] with a summary line, and one
      that does not hold fails the run with {!Failure.Make.Unmet_postconditions}
      at event ["end"].

      With [end_state] (the plan's promises and the game's reader of them), once
      the end flags hold the game reads what the plan promises and every one
      must pass ({!Engine_rules.POSTCONDITIONS.check}); one failed or not read
      fails the run with {!Failure.Make.Unmet_postconditions}. Each is logged as
      ["[Postcondition] <checkpoint> <what>: <verdict>: <detail>"] with a
      summary line. Without [end_state] (a plan that states no postconditions,
      or none the game checks at the end) nothing is read.

      [on_event index progress] hears each event (index from 0) start, pass,
      fail (with the reason as logged) or be skipped, next to its log line (the
      watch page's plan). [say] hears every line the run logs.

      With [events], only those events run ({!Event_range}), numbered as in the
      whole checkpoint, and a range that starts past the first event does not
      check [end.is] before it; the start is logged as
      ["[Story] <checkpoint>: start at #13 <event>, to #14 <event>, of 14
       events"]. A range that stops before the last event checks none of
      [end_at], [end.is] and [end_state] (logged as
      ["... stopped after #<n> (--to-event): end not checked"]). *)
end
