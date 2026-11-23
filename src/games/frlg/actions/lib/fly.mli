(** Fly to a town from the overworld: START, POKéMON, the Fly user's slot, FLY
    on its menu, the town on the fly map, then the warp settle until the player
    stands in the town. Ported from the fork's AutoStory fly step
    (PokemonFRLG_AutoStoryFieldMoves: [open_fly_map()], [fly_to_town()]).

    The Start menu and the party are read. The member's menu and the fly map
    have no reader here yet, so those two are waited out by time
    ({!member_menu_wait_ms}, {!fly_map_wait_ms}); the landing is the settle
    after a warp (a fade first, then a quiet overworld). *)

type plan = {
  town : Fly_towns.town;
  slot : int;  (** The Fly user's party slot, from 1. *)
  menu_row : int;
      (** FLY's row on its menu, from 1: SUMMARY, then the field moves in move
          order, so 2 when Fly is the only one. *)
}

val member_menu_wait_ms : int
val fly_map_wait_ms : int

val pokemon_row : int
(** The Start menu's POKéMON row once the player has the Pokédex: 1. *)

val menu_moves : from:int -> to_:int -> Wire.command list
(** Taps down (or up) that move a menu's cursor from row [from] to [to_]. *)

val fly : log:(string -> unit) -> plan -> (unit, Story.Failure.cause) result
(** Fails as [fly_no_start_menu], [fly_no_party] or, from the settle, [battle]
    or [not_settled]. *)
