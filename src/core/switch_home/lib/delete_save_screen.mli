(** Reader: the screens of System Settings > Data Management > Delete Save Data
    that the delete-save route stops on, read on the whole 1920x1080 frame (the
    daemon's [native] viewport). The lab's delete-save route (2026-11-15/25)
    read the game's title with OCR; there is no OCR probe here, so the game is
    told by its icon instead, a [core.template_match@1] probe per game.

    - The game's page: "<game title>" over "Delete Save Data for <user>", that
      row selected (its blue frame's top edge). Manage Software's page for the
      same game has the same header and icon, but its selected row sits lower,
      under the version line, so it is not this page.
    - The Caution screen ("Deleted data cannot be recovered."): its red Delete
      Save Data button, and whether its blue selection frame is round it. The
      button is greyed for about 3 s after the screen opens; no capture of that
      state was taken, so a greyed button reads as no red button.
    - "Successfully deleted save data." with its OK button selected. *)

type game = { key : string; icon : Effects.template_hash }
(** A game as the page reader knows it: a short key (its probe's id) and its
    uploaded icon template, in frame pixels. *)

val native : Wire.box -> bool
(** The game picture is the whole frame: these screens' boxes and the icon
    templates are in frame pixels. *)

val icon_probe : game -> Wire.probe_spec
(** The game's icon match on its page, on the [native] viewport: {!is_game}. *)

val colour_probes : Wire.probe_spec list
(** The colour probes the other readers need, on the [native] viewport. *)

val icon_id : string -> string
(** The icon probe's id for a game's key. *)

val max_icon_score : float
(** 0.02: the most a game's icon match scores on its own page. *)

val game_page : Effects.measurements -> bool
(** A game's "Delete Save Data for <user>" page, that row selected. *)

val is_game : string -> Effects.measurements -> bool
(** The page's icon is the game's with this key ({!max_icon_score}). *)

type caution =
  | Red_selected  (** the red button, selected: A deletes *)
  | Red_not_selected  (** the red button, Cancel selected *)
  | No_red_button  (** not the Caution screen, or its button still greyed *)

val caution : Effects.measurements -> caution
val caution_to_string : caution -> string

val deleted : Effects.measurements -> bool
(** "Successfully deleted save data." with its OK button selected. *)
