(** FRLG's Easy Chat groups and their words, in the order the editor lists them,
    from the file
    [src/games/frlg/assets/extract/extract_frlg_easy_chat_words.py] writes
    (pret/pokefirered's [src/data/easy_chat/] and [PopulateECGroups]). The grid
    lists only the groups the save has unlocked and the POKéMON group only the
    species seen, so a group's position and a word's are found on screen; these
    lists give the names to read there. *)

type shown =
  | Seen  (** Any Pokémon seen; its words only the species seen. *)
  | Always
  | Game_clear  (** FLAG_SYS_GAME_CLEAR: EVENTS, MOVE 1, MOVE 2. *)
  | National  (** The National Pokédex: POKéMON2. *)

type group = {
  id : int;  (** The EC_GROUP_ value (POKéMON is 0x15, POKéMON2 0). *)
  shown : shown;
  name : string;  (** As the grid shows it: ["MOVE 1"]. *)
  words : string list;  (** As the word list shows them, top left first. *)
}

type t = group list
(** In the grid's order. *)

val of_string : string -> (t, string) result
(** Parses the file's text: [<id> <shown> <name>|<word>|...] per line, [#] lines
    left out. *)

val load : string -> (t, string) result

val group : t -> string -> group option
(** The group of this name. *)

val names : t -> string list
(** Every group's name, in the grid's order. *)

val look_alikes : group -> string -> string list
(** The group's words that start with the word's first letter (the word itself
    among them when it is in the group): the candidates a list cell is read
    against while the cursor looks for the word, so that a near word (BIDE for
    BIND) reads as itself, not as the word. *)
