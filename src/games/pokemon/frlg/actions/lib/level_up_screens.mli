(** Which {!Level_up.look} a frame shows. The list to forget from, the evolution
    scene and its YES/NO box are the same in every context (pokefirered: the
    summary's moves page; evolution_scene.c draws the battle's text box and
    YES/NO window), so they are read here; a context gives only its own screens:
    its stats window, its YES/NO box, and where it ends. *)

type context = {
  stats : Effects.measurements -> bool;  (** the context's stats window *)
  question : Effects.measurements -> bool;  (** the context's YES/NO box *)
  back : Effects.measurements -> bool;  (** where the context ends *)
}

val probes : Wire.probe_spec list
(** The shared screens' readers': the battle's ({!Frlg_battle.Battle_look}),
    which hold the evolution scene, its YES/NO and the summary. *)

val forget_list : Effects.measurements -> bool
(** The summary's moves page with its cursor read. *)

val evolution_question : Effects.measurements -> bool
(** The evolution scene's YES/NO: the battle's box
    ({!Frlg_readers.Battle_yes_no.yes_no_box}). *)

val question : context -> Effects.measurements -> bool
(** The context's YES/NO box or the evolution scene's. *)

val classify : context -> Effects.measurements -> Level_up.look option
(** The list to forget from, a YES/NO box, the stats window, the context's end,
    the evolution scene, in that order; [None] for anything else (text, a fade).
    Names are not read: [Stats None], [Evolving None]. *)
