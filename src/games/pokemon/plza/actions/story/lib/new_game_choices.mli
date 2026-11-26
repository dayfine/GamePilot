(** The new game's choices, 01.00a-new-game's: the language, the look and the
    name, and whether 01.00a-new-game can play them. Ported from
    PokemonLZA_AutoStoryNewGame.h and .cpp (branch [lab/dev-plza-slice1]): its
    languages in the list's order, each one's tag, entry and name limit, its
    defaults (English, look 1, "Kosmos") and its refusals.

    Where it differs: Simplified Chinese is refused too. Its keyboard opens in
    Pinyin, and the fork presses the keyboard's English key on the bottom row
    first, which the cursor reader here does not read
    ({!Switch_home.Keyboard_typing}). *)

(** In the language list's order: down the left column, then the right one. *)
type language =
  | English  (** en, English *)
  | Spanish_spain  (** es-ES, Español (España) *)
  | Spanish_latin_america  (** es-419, Español (Latinoamérica) *)
  | French  (** fr, Français *)
  | German  (** de, Deutsch *)
  | Italian  (** it, Italiano *)
  | Japanese  (** ja, 日本語 *)
  | Korean  (** ko, 한국어 *)
  | Chinese_simplified  (** zh-Hans, 简体中文 *)
  | Chinese_traditional  (** zh-Hant, 繁體中文 *)

type language_info = {
  tag : string;  (** For logs and plans: ["en"], ["es-ES"], ... *)
  list_entry : int;  (** Its entry in the language list, 0 to 9. *)
  name_limit : int;  (** The name keyboard's limit: 12, or 6 in East Asian. *)
  typed : bool;
      (** Whether 01.00a-new-game types a name on its keyboard: not Korean's
          (Hangul) nor Simplified Chinese's (Pinyin). *)
}
(** What 01.00a-new-game needs to know of a language. *)

val info : language -> language_info
(** The language's tag, list entry, name limit and whether 01.00a-new-game types
    in it. *)

val of_tag : string -> language option
(** The language with this tag. *)

val tags : string list
(** Every language's tag, in the list's order. *)

type t = {
  language : language;
  look : int;  (** 1 to 8: left to right along the top row, then the bottom. *)
  name : string;  (** The player's name, typed on the keyboard. *)
}
(** The new game's three choices. *)

val default : t
(** English, look 1, "Kosmos". *)

val looks : int
(** 8. *)

val problem : t -> string option
(** Why 01.00a-new-game cannot play the choices, before any press: a look
    outside 1 to 8, an empty name, a name longer than the language takes
    (counted in characters), a keyboard 01.00a-new-game does not type on, or a
    character not on the keyboard's first page
    ({!Switch_home.Keyboard_typing.key_of_char}); [None] when it can. *)

val by_hand_hint : string
(** What every refusal and failure of 01.00a-new-game ends with: make the
    choices by hand up to Confirm Choices, then start at 01.00b. *)

val typed_tags : string list
(** The language tags 01.00a-new-game types a name in. *)

val decls : Run_options.decl list
(** plza.autostory's options, the choices given on the command line
    ([gamepilot run --options], Program_registry): [language] (one of
    {!typed_tags}), [look] (1 to {!looks}) and [name] (text), each optional: a
    key not given keeps 01.00a-new-game's plan's arg. *)
