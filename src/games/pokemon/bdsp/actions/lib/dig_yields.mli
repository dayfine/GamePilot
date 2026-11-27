(** Post-dig item spotlight yield collector for the BDSP Grand Underground. *)

open Bdsp_underground

val collect :
  log:(string -> unit) ->
  picture:Wire.box ->
  unit ->
  Mining_counters.treasure list
(** Advances post-dig dialog and item spotlights until the overworld returns,
    returning each uncovered treasure in order. *)
