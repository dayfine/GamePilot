(** Fly to a town from the overworld: START, POKéMON, the Fly user's slot, FLY
    on its menu, the town on the fly map, then the warp settle until the player
    stands in the town. Ported from the fork's AutoStory fly step
    (PokemonFRLG_AutoStoryFieldMoves: [open_fly_map()], [fly_to_town()]).

    The Start menu, the party and the member's menu are read ({!Menu_cursor}).
    The fly map has no reader here yet, so it is waited out by time
    ({!fly_map_wait_ms}) and its cursor moved by counted presses. The landing is
    the fork's judge (PokemonFRLG_AutoStoryFlyLanding: [judge_fly_landing()]):
    the settle after a warp (a fade first, then a quiet overworld), then the
    screen showing another scene than the overworld before the Fly
    ({!Frlg_readers.Scene_signature}, for the fork's [left_departure()]). The
    fork also reads the player's facing; no reader for it here. *)

type plan = {
  town : Fly_towns.town;
  slot : int;  (** The Fly user's party slot, from 1. *)
  menu_row : int;
      (** FLY's row on its menu, from 1: SUMMARY, then the field moves in move
          order, so 2 when Fly is the only one. *)
}

val fly_map_wait_ms : int

val fly : log:(string -> unit) -> plan -> (unit, Story.Failure.cause) result
(** Fails as [no_start_menu], [no_party], [no_member_menu] or, from the settle,
    [battle] or [not_settled], or [fly_no_landing] when the screen still shows
    the departure town (the fly map closed and nothing happened). *)

val left_departure_ms : int
(** 2000: after the settle, how long the screen may take to show another scene
    than the departure town. *)
