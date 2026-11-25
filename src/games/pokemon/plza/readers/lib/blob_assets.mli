(** The PNGs the PLZA readers' [core.find@1] probes name: the template crops and
    the advance chevron's shape in [src/games/pokemon/plza/assets/templates]
    (written by assets/extract/write_find_templates.py). A probe names each by
    the daemon's reference for it: an uploaded PNG's hash, or, for the offline
    [probe_images] tool, the PNG's path relative to the spec file. *)

type t = {
  dialog_white_arrow : string;  (** the blue box's white arrow *)
  dialog_black_arrow : string;  (** the white box's black arrow *)
  dialog_teal_arrow : string;  (** the teal box's arrow *)
  choice_arrow : string;  (** the arrow at a choice box's row *)
  advance_chevron_shape : string;  (** the chevron's V *)
}
(** One path or file name for each template and shape the readers match. *)

val folder : string
(** ["src/games/pokemon/plza/assets/templates"], from the repo root. *)

val file_names : t
(** Each asset's file name in {!folder}: the references of a [probe_images] spec
    written beside copies of them. *)
