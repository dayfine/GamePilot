(** The FRLG readers [gamepilot ctl read NAME] runs once on the current frame:
    the screen readers (games/pokemon/frlg/readers) and the text readers the
    actions use (Start_menu_names, Party_species, Summary_moves), each
    subscribed for one frame and printed as [field: value] lines. Nothing here
    presses a button. *)

type reader = Ctl_script.reader = {
  name : string;
  doc : string;
  read : unit -> (string * string) list;
}
(** A reader [read NAME] runs (Ctl_script.reader), re-exported so the table's
    records can be written here. *)

val all : reader list
(** Every FRLG one-shot reader registered for [gamepilot ctl read NAME]. *)
