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
  button_a : string;  (** the A button of a prompt ("A Talk") *)
  button_minus : string;  (** the Run prompt's minus button in a wild battle *)
  alert_eye : string;  (** the eye on the alert bar of a wild Pokemon *)
  button_dpad_up : string;
      (** the party bar's D-pad markers: up, down, and their black insides *)
  button_dpad_down : string;
  button_dpad_up_interior : string;
  button_dpad_down_interior : string;
  move_no_effect : string;  (** a move's effectiveness symbols under ZL *)
  move_not_very_effective : string;
  move_effective : string;
  move_super_effective : string;
}
(** One path or file name for each template and shape the readers match. *)

val folder : string
(** ["src/games/pokemon/plza/assets/templates"], from the repo root. *)

val file_names : t
(** Each asset's file name in {!folder}: the references of a [probe_images] spec
    written beside copies of them. *)
