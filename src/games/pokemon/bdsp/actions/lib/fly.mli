(** Reusable Sinnoh Town Map Fly action for Pokémon BDSP.

    Mirrors FRLG's {!Frlg_actions.Fly} / {!Frlg_actions.Fly_towns}: opens the
    Town Map via [X -> +], clamps the cursor to the top-left corner so it works
    from any outdoor Sinnoh location, looks up the destination's [(x, y)] grid
    offset in {!known_towns}, confirms Fly ([A -> A]), and waits for the black
    transition fade to complete. *)

val oreburgh_city : string
(** Oreburgh City (drops into the Central Grassland Cave hallway). *)

val celestic_town : string
(** Celestic Town (drops into the isolated Stargleam Cavern zone). *)

val ramanas_park : string
(** Ramanas Park on Route 221. *)

val known_towns : (string * (int * int)) list
(** All calibrated Sinnoh Town Map destinations as [(name, (x, y))] offsets from
    the top-left corner-clamped cursor. Add remaining Sinnoh towns from BDSP
    Town Map data / decomp as future programs need them. *)

val coordinates : string -> (int * int) option
(** Look up a town's [(right_taps, down_taps)] Town Map offset in the Sinnoh
    lookup map, if known. *)

val fly_to :
  log:(string -> unit) ->
  picture:Wire.box ->
  string ->
  unit ->
  (unit, string) result
(** Fly from any outdoor Sinnoh location to [town]. Returns [Error] if [town] is
    not in {!known_towns} or if the Fly transition fails. *)
