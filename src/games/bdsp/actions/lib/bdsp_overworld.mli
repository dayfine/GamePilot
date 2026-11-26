(** Primitive overworld, Grand Underground doorway, menu, dialog, and battle-
    escape actions for BDSP, built on
    {!Bdsp_underground.Corridor_nav.bdsp_move_mechanics} (fork PR #402) and
    {!Switch_home.Switch_presses}. *)

open Bdsp_underground

val button_of_dir : Corridor_nav.direction -> Wire.button
(** Map a cardinal {!Corridor_nav.direction} to its Switch D-pad button. *)

val turn : Corridor_nav.direction -> unit
(** 50 ms turn tap in place. *)

val step_tap : Corridor_nav.direction -> int -> unit
(** Walk [n] tiles using BDSP step taps (160 ms hold / 640 ms release) to avoid
    open-leg drift. *)

val run_hold : Corridor_nav.direction -> hold_ms:int -> unit
(** Hold B + D-pad in [dir] for [hold_ms] (for wall-bounded corridor slides). *)

val pulse_radar : unit -> unit
(** Press R in the Grand Underground to pulse the dig-spot radar. *)

val interact : unit -> unit
(** Press A to interact with a sparkling wall or dialog. *)

val bounce_doorway :
  log:(string -> unit) ->
  picture:Wire.box ->
  anchor:Corridor_nav.doorway_anchor ->
  ?hold_ms:int ->
  unit ->
  (unit, string) result
(** Walk through a Pokémon Hideaway doorway (with perpendicular 1-tile
    auto-centering nudge if off-center) until the black room transition
    finishes, then immediately walk back out until the corridor reloads. *)

val open_menu :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Port of [overworld_to_menu] from [PokemonBDSP_GameNavigation.cpp]: press X
    and wait for {!Bdsp_readers.Menu_detector.shown}. *)

val close_menu :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Press B and wait until {!Bdsp_readers.Menu_detector.shown} clears. *)

val dismiss_dialog :
  log:(string -> unit) ->
  picture:Wire.box ->
  ?max_presses:int ->
  unit ->
  (unit, string) result
(** Press B up to [max_presses] times until
    {!Bdsp_readers.Dialog_detector.shown} is false. *)

val advance_dialog :
  log:(string -> unit) ->
  picture:Wire.box ->
  ?max_presses:int ->
  unit ->
  (unit, string) result
(** Press A up to [max_presses] times until
    {!Bdsp_readers.Dialog_detector.shown} is false (e.g. post-dig results). *)

val menu_select :
  log:(string -> unit) ->
  picture:Wire.box ->
  dx:int ->
  dy:int ->
  unit ->
  (unit, string) result
(** From an open X menu, move the cursor by [(dx, dy)] and press A until the X
    menu closes into the selected sub-screen. *)

val use_explorer_kit_offline :
  log:(string -> unit) ->
  picture:Wire.box ->
  explorer_kit_row:int ->
  unit ->
  (unit, string) result
(** From the overworld with Bag selected on the X menu and Key Items active,
    open Bag, move down [explorer_kit_row] rows to the Explorer Kit, choose Use
    -> Play Alone (row 2: Down 2 + A), and wait for the Grand Underground
    transition fade. *)

val run_from_battle :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Escape a wild battle once {!Bdsp_readers.Battle_detector.shown} appears:
    press Up -> A (Run) and wait for the battle-end fade to clear. *)
