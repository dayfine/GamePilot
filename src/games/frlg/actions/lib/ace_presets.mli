(** frlg.ace's vetted table: the box-name codes and the items each makes, read
    from [src/games/frlg/assets/ace_presets.json]
    (docs/design/FRLG-ACE-Execution.md, "Codes and the vetted table, as data").
    The names are the literal text typed on the naming screen, so what is typed
    is what was reviewed. New, not in the fork, which has no ACE.

    A code names the boxes every item shares and the boxes each item fills; the
    table is refused when an item's boxes and its code's do not name Boxes 1 to
    {!boxes} once each, or a name is empty, longer than
    {!Naming_entry.box_name_chars}, only spaces, or holds a character the
    keyboard does not type ({!Frlg_text.Naming_keyboard.chars}). *)

type item = {
  slug : string;  (** ["master-ball"]: the run option's value. *)
  id : int;  (** The item's index in the game (pret's [ITEM_*]). *)
  names : string list;  (** The 14 box names, Box 1 first. *)
}
(** One item the table makes. *)

type t = { items : item list  (** In the file's order. *) }
(** The table. *)

val asset : string
(** The table's path from the repo root. *)

val boxes : int
(** 14: every box is named. *)

val parse : Yojson.Safe.t -> (t, string) result
(** The table, or why it is refused. *)

val load : unit -> (t, string) result
(** The table, found from the working directory ({!Repo_io.Repo_files.locate})
    and read once. *)

val slugs : t -> string list
(** Every item's slug, in the file's order. *)

val find : t -> string -> item option
(** The item a slug names. *)

val box_name : item -> int -> string
(** The item's name for box [b] (1 to {!boxes}). *)

val known_names : t -> int -> string list
(** Every name box [b] may hold before or after a run: the game's default
    (["BOX<b>"]) and each item's name for it, each once. *)
