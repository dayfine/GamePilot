(** Closed-loop minimap navigator for the right half of the central Grand
    Underground Hideaway ring ([bottom_east], [east_vertical], [top_east]).

    Sprints directly to each active {!Bdsp_readers.Minimap_sparkles.target}
    bucket using the pink player dot position, then micro-probes the wall at
    that bucket and calls [on_prompt] whenever a dig dialog or wild battle
    triggers. *)

val visit_targets :
  log:(string -> unit) ->
  picture:Wire.box ->
  sparkles:Bdsp_readers.Minimap_sparkles.nearby ->
  on_prompt:('a -> ('a * bool, string) result) ->
  on_battle:('a -> ('a, string) result) ->
  'a ->
  ('a, string) result
(** Sprint to each active sparkle bucket in [sparkles], probe the adjacent wall,
    and return to the South Hideaway doorway. *)
