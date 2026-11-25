(** Turns the player to face a minimap bearing by the minimap's arrow. Ported
    from [face_heading] in PokemonLZA_AutoStoryWalks.cpp ([plza/lean]), with
    [get_facing_direction] (PokemonLZA_BasicNavigation.cpp) as its arrow read.

    Reads the arrow; up to 4 turns, each an L tap (100/150 ms) and the stick
    toward the turn left to make (150 ms, released 100 ms, walking), until the
    arrow reads within 4 degrees (turns land within 2; at 8 off a 6.5 s leg
    misses a gate): then an L tap, and it faces the bearing. Small turns
    overshoot (5 asked, 10 turned), so after a turn past the bearing the next
    asks half as much. After a turn the arrow is read up to 10 times, 100 ms
    apart, until it has moved half the turn (the lab feed has run 0.4 s behind
    the game). Still off after 4 turns: [heading_missed].

    The arrow read waits for the arrow up to 40 s (a day and night change), as
    the fork's; none by then: [arrow_unread] (the fork throws, which its runner
    reports as [operation_failed]).

    Where it differs: the arrow is waited for by screen reads 100 ms apart, not
    by a watcher held 50 ms. *)

type game_steps = {
  submit : Wire.command -> unit;  (** Send one input and return once done. *)
  read_arrow : unit -> float option;
      (** Read the minimap's arrow on the latest frame. *)
  log_detail : string -> unit;  (** A line for the log alone. *)
}
(** What facing a bearing reads and does in the game. *)

val screen_game_steps :
  submit:(Wire.command -> unit) ->
  read_screen:(unit -> Walk_screen.t) ->
  log_detail:(string -> unit) ->
  game_steps
(** The steps, with the arrow read off a walk's screen read. *)

val face : game_steps -> float -> (unit, Engine_run.Failure.cause) result
(** [face steps heading]: the player faces [heading], or why not. *)

val turn_to : float -> float -> float
(** [turn_to now heading]: the turn from [now] to [heading], in (-180, 180]. *)
