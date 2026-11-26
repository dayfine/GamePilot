type language =
  | English
  | Spanish_spain
  | Spanish_latin_america
  | French
  | German
  | Italian
  | Japanese
  | Korean
  | Chinese_simplified
  | Chinese_traditional

type language_info = {
  tag : string;
  list_entry : int;
  name_limit : int;
  typed : bool;
}

let latin_limit = 12
let east_asian_limit = 6

let row tag list_entry name_limit =
  { tag; list_entry; name_limit; typed = true }

(* new_game_language_info's table. *)
let info = function
  | English -> row "en" 0 latin_limit
  | Spanish_spain -> row "es-ES" 1 latin_limit
  | Spanish_latin_america -> row "es-419" 2 latin_limit
  | French -> row "fr" 3 latin_limit
  | German -> row "de" 4 latin_limit
  | Italian -> row "it" 5 latin_limit
  | Japanese -> row "ja" 6 east_asian_limit
  | Korean -> { (row "ko" 7 east_asian_limit) with typed = false }
  | Chinese_simplified ->
      { (row "zh-Hans" 8 east_asian_limit) with typed = false }
  | Chinese_traditional -> row "zh-Hant" 9 east_asian_limit

let all =
  [
    English;
    Spanish_spain;
    Spanish_latin_america;
    French;
    German;
    Italian;
    Japanese;
    Korean;
    Chinese_simplified;
    Chinese_traditional;
  ]

let tags = List.map (fun l -> (info l).tag) all
let of_tag tag = List.find_opt (fun l -> (info l).tag = tag) all

type t = { language : language; look : int; name : string }

let default = { language = English; look = 1; name = "Kosmos" }
let looks = 8

let by_hand_hint =
  "Make the new game's choices by hand up to \"Confirm Choices\", then start \
   the run at 01.00b."

(* utf8_to_utf32's length: the bytes that do not continue a character. *)
let continuation_mask = 0xC0
let continuation = 0x80

let characters name =
  String.fold_left
    (fun n ch ->
      if Char.code ch land continuation_mask = continuation then n else n + 1)
    0 name

(* choices_problem. *)
let choices_problem c =
  let i = info c.language in
  let n = characters c.name in
  if c.look < 1 || c.look > looks then
    Some
      (Printf.sprintf "AutoStory: the player look must be 1 to %d, not %d."
         looks c.look)
  else if c.name = "" then Some "AutoStory: the player name is empty."
  else if n > i.name_limit then
    Some
      (Printf.sprintf
         "AutoStory: the player name \"%s\" has %d characters; the game takes \
          at most %d in this language (%s)."
         c.name n i.name_limit i.tag)
  else None

let keyboard_name = function
  | Korean -> "Hangul"
  | Chinese_simplified -> "Pinyin"
  | English | Spanish_spain | Spanish_latin_america | French | German | Italian
  | Japanese | Chinese_traditional ->
      "Latin"

(* name_typing_problem. *)
let typing_problem c =
  let i = info c.language in
  if not i.typed then
    Some
      (Printf.sprintf
         "AutoStory: the program cannot type a name on the %s keyboard (%s)."
         i.tag (keyboard_name c.language))
  else if Switch_home.Keyboard_typing.missing c.name <> "" then
    Some
      (Printf.sprintf
         "AutoStory: the player name \"%s\" has a character that is not on the \
          name keyboard's first page (letters, digits and - / : ' , . ? !)."
         c.name)
  else None

let problem c =
  match choices_problem c with Some p -> Some p | None -> typing_problem c

let typed_tags =
  List.filter
    (fun tag ->
      match of_tag tag with Some l -> (info l).typed | None -> false)
    tags

let decls : Run_options.declared list =
  [
    {
      key = "language";
      value = One_of typed_tags;
      presence = Optional;
      doc = "the new game's language (01.00a-new-game; not given: the plan's)";
    };
    {
      key = "look";
      value = Int_range (1, looks);
      presence = Optional;
      doc =
        "the new game's look, left to right along the top row, then the bottom \
         (not given: the plan's)";
    };
    {
      key = "name";
      value = Text;
      presence = Optional;
      doc =
        "the player's name: at most 12 characters (6 in Japanese and Chinese), \
         letters, digits and - / : ' , . ? ! (not given: the plan's)";
    };
  ]
