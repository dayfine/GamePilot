(** The naming screen's keys: what each key of each page types, from pokefirered
    src/naming_screen.c ([sKeyboardChars]), as the English game has them. New,
    not in the fork. A key the grid leaves short (the letter pages' rows 2 and 3
    have 7 characters for 8 columns, the others page's first two rows 5 for 6)
    types a space; so do the blank keys of column 6 on the letter pages. Every
    character is one UTF-8 string: ["♂"], ["…"], ["“"]. The last key of the
    others page is the game's right single quote, drawn and written here as
    ["'"]. *)

type position = {
  page : Frlg_readers.Naming_screen.page;
  key : Frlg_readers.Naming_screen.key;
}
(** A key on a page. *)

val char_at :
  Frlg_readers.Naming_screen.page -> Frlg_readers.Naming_screen.key -> string
(** What the key types; [" "] for a space. *)

val page_chars : Frlg_readers.Naming_screen.page -> string list
(** Every character the page types, a space last, each once. *)

val charset : string list
(** Every character the keyboard types: the capitals, the small letters, the
    digits, [. , ! ? ♂ ♀ / - … “ ” ‘ '] and the space. *)

val find : on:Frlg_readers.Naming_screen.page -> string -> position option
(** Where to type this character: on page [on] when it has it (a space, the full
    stop and the comma are on both letter pages), else on the first page of the
    capitals, the small letters and the others that has it. *)

val chars : string -> (string list, string) result
(** The text's characters, each one the keyboard types; [Error] naming the first
    that it does not (an accented letter: the English keyboard has none). *)

val next_page :
  Frlg_readers.Naming_screen.page -> Frlg_readers.Naming_screen.page
(** The page SELECT turns to: capitals, small letters, others, capitals
    ([MainState_WaitPageSwap]). *)
