(** Reusable Sinnoh Town Map Fly action for Pokémon BDSP.

    Mirrors FRLG's {!Frlg_actions.Fly} / {!Frlg_actions.Fly_towns}: opens the
    Town Map via [X -> +], clamps the cursor to the top-left corner so it works
    from any outdoor Sinnoh location, steps to the destination's calibrated grid
    offset, confirms Fly ([A -> A]), and waits for the black transition fade to
    complete. *)

(** Calibrated Sinnoh Town Map Fly destinations (add new towns here as BDSP
    AutoStory / post-game programs need them). *)
type destination =
  | Oreburgh
      (** Oreburgh City (drops into the Central Grassland Cave hallway). *)
  | Celestic
      (** Celestic Town (drops into the isolated Stargleam Cavern zone). *)
  | Ramanas_park  (** Ramanas Park on Route 221. *)

val destination_name : destination -> string
(** Human-readable destination name for logs. *)

val map_offset : destination -> int * int
(** [(right_taps, down_taps)] from the top-left corner-clamped Town Map cursor.
*)

val fly_to :
  log:(string -> unit) ->
  picture:Wire.box ->
  destination ->
  unit ->
  (unit, string) result
(** Fly from any outdoor Sinnoh location to [destination]. *)
