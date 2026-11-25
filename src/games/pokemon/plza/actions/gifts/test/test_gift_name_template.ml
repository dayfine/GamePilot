(* Claim_gifts.gift_name_template: the game's language picks the Internet
   gift's name template, and a run that reads the gift list in a language
   with none is refused before any press; a run that does not read it (the
   code alone, a start past the list, a stop on it) needs none. *)

module C = Plza_gifts.Claim_gifts

let span ?(from = "overworld") ?stop_at ?(mode = C.Both_gifts) () : C.span =
  { from; stop_at; mode }

let template language span () =
  match C.gift_name_template ~language span with
  | Ok (Some path) -> path
  | Ok None -> "none needed"
  | Error e -> "error: " ^ e

let case name input expectation : Table_test.case = { name; input; expectation }

let refusal =
  "error: no template of the Internet gift's name in language de (there is one \
   in en, fr); crop one from its gift list as \
   src/games/pokemon/plza/assets/gift-name-vivillon-en.png was, or claim the \
   code alone (--code-only)"

let () =
  Table_test.run "gift_name_template"
    [
      case "English"
        (template "en" (span ()))
        "src/games/pokemon/plza/assets/gift-name-vivillon-en.png";
      case "French"
        (template "fr" (span ()))
        "src/games/pokemon/plza/assets/gift-name-vivillon-fr.png";
      case "German, the whole run: refused" (template "de" (span ())) refusal;
      case "German, from the gift list: refused"
        (template "de" (span ~from:"gift-list" ()))
        refusal;
      case "German, the code alone"
        (template "de" (span ~mode:Code_gift_only ()))
        "none needed";
      case "German, from the card"
        (template "de" (span ~from:"card" ()))
        "none needed";
      case "German, stopped on the gift list"
        (template "de" (span ~stop_at:"gift-list" ()))
        "none needed";
    ]
