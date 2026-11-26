(** Composite screen-state reader for BDSP Grand Underground runs, modeled on
    PLZA's [Story_screen] and feeding GamePilot's shared {!Screen_state.Facts}.

    Mutual-exclusion rules applied on every frame:
    - A black or white fade ({!Screen_state.Fade}) suppresses dialog, menu,
      mining-wall, battle, and minimap readings.
    - An active mining wall ({!Mining_grid.on_mining_screen}) suppresses
      [battle] so the right-side Red Hammer and Blue Pickaxe buttons can never
      false-trigger {!Battle_detector}.
    - Minimap sparkles are read only in the free overworld (no fade, dialog,
      menu, battle, or mining wall). *)

type t = {
  fade : Screen_state.Fade.t;
  mining_wall : bool;
  dialog : bool;
  choice_box : bool;
      (** White Yes/No choice box ([是 / 否]) above the dialog box, shown on
          dig-spot confirmation prompts ([牆壁有點隆起。要挖挖看嗎？]). *)
  menu : bool;
  battle : bool;
  sparkles : Minimap_sparkles.nearby;
}
(** Classified state of one BDSP Grand Underground frame. *)

val probes : picture:Wire.box -> Wire.probe_spec list
(** All probes needed by {!read} (fade, dialog, menu, battle, mining tool panel,
    and 3-zone minimap sparkles), relative to [picture]. *)

val read : Effects.measurements -> t
(** Classify one frame's measurements into a mutually-consistent {!t}. *)

val to_facts : t -> Screen_state.Facts.t
(** Project {!t} into {!Screen_state.Facts.t} for {!Screen_state.Settle}. *)

val to_string : t -> string
(** Human-readable summary for logs and the watch page, e.g. ["black fade"],
    ["mining_wall"], or ["overworld (sparkles: bottom_east, top_east)"]. *)
