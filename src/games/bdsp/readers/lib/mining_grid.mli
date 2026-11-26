(** Reader: the 13x10 BDSP Grand Underground mining wall grid.

    Grid geometry and cell colour statistics were measured from live Switch
    captures on Console A ([run-15/frames/000019.jpg],
    [run-16/frames/000018.jpg]):
    - Grid box (normalized): [x = 0.1328..0.7484], [y = 0.1111..0.9556]
    - 13 columns x 10 rows; each cell is probed on its inner 60% patch via
      [Wire.color_stats_probe]. *)

open Bdsp_underground

val cols : int
(** Width of the mining grid (13 columns). *)

val rows : int
(** Height of the mining grid (10 rows). *)

val cell_probe_id : col:int -> row:int -> string
(** Probe id for cell [(col, row)] in {!probes}. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** The 130 [color_stats_probe] specs (13x10 grid), relative to [picture]. *)

val classify_cell : Switch_home.Solid_color.stats -> Mining_wall.visible_cell
(** Classify one cell's RGB mean/stddev into covered dirt (1/2/4), cleared
    empty wall, iron bar, or exposed item (distinguishing pink/magenta
    Mysterious Shards from other items). *)

val read_observation :
  ?cursor:int * int ->
  ?prev:Mining_wall.visible_cell array array ->
  announced_items:int ->
  integrity:int ->
  Effects.measurements ->
  Mining_wall.observation
(** Read the full 13x10 {!Mining_wall.observation} from daemon measurements,
    ready to pass directly to {!Mining_solver.decide}. When [cursor] is given,
    cells occluded by the tool/cursor sprite ([(c..c+1, r-1..r)]) keep their
    previous value from [prev] (or [Covered 2] on the first frame) so the red
    hammer never triggers a false item read. *)
