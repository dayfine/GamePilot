(** Runs a checkpoint's events in order through a game's handlers
    ({!Game.Make.t}).

    Before any event runs, every game action the checkpoint names must have a
    handler. Then, per event: it is skipped when a flag its [skip_if] names
    holds; otherwise its handler runs, and once it passes, the game's position
    (when it can tell) must match its [declared_after]
    ({!Engine_terms.GAME_TERMS.matches}). The first event that fails stops the
    run. Each event's start (with its [why]), skip, end and failure is logged as
    ["[Story] <checkpoint> #<n> <event>: ..."]. A handler that raises is logged
    as failed and the exception passes through.

    An event's [once_per_save] is the game's to honour in its handler: only the
    game knows what its save already holds. The runner neither saves nor
    reloads: the caller (or {!Repeat_until}) decides that. *)

open Engine_plan

(** The runner over the game's terms. *)
module Make (T : Engine_terms.GAME_TERMS) : sig
  val run :
    ?end_at:T.pose ->
    ?end_state:T.promises * (T.promises -> T.reads) ->
    ?on_event:(int -> Event_progress.t -> unit) ->
    ?events:Event_range.t ->
    Game.Make(T).t ->
    Plan.Make(T).checkpoint ->
    (unit, Failure.Make(T).t) result
  (** With [end_at] (the checkpoint's declared end), after the last event the
      player must read there, or the run fails with {!Failure.Make.Not_at_end}
      (also when the game cannot tell where they are), logged as
      ["[Story] <checkpoint> end <pose>: holds"] or [": failed: ..."]. The C++
      end check is [check_postconditions()] (map and tile) in
      [Pokemon/AutoStory/Pokemon_StoryPostconditionCheck.cpp] on the fork's
      [frlg/lean].

      With [end_state] (the plan's promises and the game's reader of them), once
      the end position holds the game reads what the plan promises and every one
      must pass ({!Engine_terms.GAME_TERMS.check}); one failed or not read fails
      the run with {!Failure.Make.Unmet_postconditions}. Each is logged as
      ["[Postcondition] <checkpoint> <what>: <verdict>: <detail>"] with a
      summary line. Promises the game does not check at the end
      ({!Engine_terms.GAME_TERMS.checked_at_end}) read nothing.

      [on_event index progress] hears each event (index from 0) start, pass,
      fail or be skipped, next to its log line (the watch page's plan).

      With [events], only those events run ({!Event_range}), numbered as in the
      whole checkpoint; the start is logged as
      ["[Story] <checkpoint>: start at #13 <event>, to #14 <event>, of 14
       events"]. A range that stops before the last event checks neither
      [end_at] nor [end_state] (logged as
      ["... stopped after #<n> (--to-event): end not checked"]). *)
end
