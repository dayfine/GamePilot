(** Reading the Mystery Gift catalog, [gifts.json] beside this library (read by
    plza.claim-gifts and pokemon_home.bank-plza), into a {!Gift_catalog.t}, and
    checking it. The file:

    {v
    { "format": "gamepilot-gifts/1",
      "gifts": [
        { "id": "xerneas-30th", "name": "Shiny Xerneas", "how": "code",
          "code": "CELEBRATE30TH", "expires": "2026-12-31",
          "box_slot": { "box": 1, "slot": 1 },
          "home_boxes": [165, 164], "home_order": "left_to_right",
          "source": "https://www.nintendolife.com/..." } ] }
    v}

    [how] is ["code"], ["internet"] or ["home"]; [code] is given for a code gift
    only; [box_slot], [home_boxes] and [home_order] ("left_to_right" or
    "right_to_left") are all given (a Pokémon) or all left out (items). Checked:
    each id once, short and lower case; a code of letters and digits; a real
    day; slots 1 to 30 of a box from 1, each slot once; HOME boxes 1 to 300; a
    source on dittobase.com, nintendolife.com or videogameschronicle.com. *)

val path : string
(** [gifts.json]'s path from the repo root. *)

val of_json : Yojson.Safe.t -> (Gift_catalog.t, string) result
(** The catalog in the file's JSON, checked; [Error] naming the gift and field
    at fault. *)
