(** Whether the Pokédex has a species seen or caught, read off its numerical
    list: the Pokédex opened from the Start menu, NUMERICAL MODE, the list's
    arrow moved to the species' number, its row read, the Pokédex closed. New:
    the fork reads no Pokédex list. The game's steps come as {!game_steps}, so
    the decisions run on a fake in tests; {!Pokedex_entry_steps} is the game's.

    pret pokefirered src/pokedex_screen.c and src/list_menu.c: the list holds
    every Kanto number from No001 to the highest seen, a seen species' name or
    ["-----"], and a Poké Ball on a caught one's row. DOWN and UP move the arrow
    one row, RIGHT and LEFT nine (a page); past the last number the arrow stays
    on it. A number above the highest seen is not in the list: not seen. The
    arrow's row on screen depends on how it got there, so each look reads the
    arrow's row and the number on it, and each tap moves toward the target from
    what was read. Kanto numbers only (1 to 151): NUMERICAL MODE is the Kanto
    list's on a save with the National Pokédex too.

    English only: the species' name a row is matched against is the English
    game's ({!Frlg_text.Species_names}, from species_names_eng); another
    language needs its own names. *)

(** What the Pokédex list shows for a species. *)
type entry =
  | Not_seen  (** dashes on its row, or its number past the list's end *)
  | Seen  (** seen, not caught *)
  | Caught  (** seen and caught: the Poké Ball on its row *)

val entry_name : entry -> string
(** ["not seen"], ["seen"], ["caught"]. *)

type shown = { row : int; number : int }
(** The list's arrow: its shown row (0..8) and the number on that row. *)

type game_steps = {
  open_list : unit -> unit;
      (** From the overworld: the Pokédex opened and its numerical list shown.
      *)
  look : unit -> shown option;
      (** The arrow and its number; [None] when they do not read. *)
  tap : Wire.button -> unit;  (** One D-pad tap on the list. *)
  entry_on : row:int -> name:string -> entry option;
      (** The shown row's entry for the species of this name: its name or the
          dashes, and the caught mark; [None] when the row shows neither. *)
  close_list : unit -> unit;  (** Back to the overworld. *)
  log : string -> unit;  (** Where {!read_with} logs the read. *)
}
(** What {!read_with} reads and does in the game. *)

val kanto_count : int
(** 151. *)

val max_taps : int
(** Taps at most before the read gives up: 40 (No001 to No151 takes 24). *)

val max_still : int
(** Taps in a row that move nothing, with the target below, before the list is
    taken to end above it: 2. *)

val number_of : Frlg_text.Species_names.t -> string -> int option
(** The species' Kanto number, by its slug (["magikarp"] is 129); [None] for an
    unknown slug or one past Mew. *)

val read_with :
  game_steps -> number:int -> name:string -> (entry, string) result
(** Opens the list, moves the arrow to [number], reads its row for [name] and
    closes the list (also after an [Error]). Logs
    ["Pokedex: MAGIKARP (No129) seen."]. *)
