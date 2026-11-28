(* frlg.ace's vetted table (src/games/pokemon/frlg/assets/ace_presets.json): each
   item's 14 box names, encoded with pret pokefirered's charmap.txt and laid
   out as the naming screen leaves them (9 bytes a box, 0xFF after the end
   mark), run as ARM words from the first box name's first byte
   (docs/design/FRLG-ACE-Execution.md, "How the code runs"). Only the words
   whose condition is AL change anything there: the LT and NV fillers are
   skipped (the 999 variant's mvnlt relies on it), and the carry is clear on
   entry, as on mGBA. The code must store 999 at +0xC6, the item's id at +0xC4,
   then exit through bic r0 / mvn r12 / rsc pc. A typo in the data fails here,
   not on the game. *)

open Frlg_actions

let table = Result.get_ok (Ace_presets.load ())

(* pret charmap.txt, the characters the codes use. *)
let charmap =
  [
    (" ", 0x00);
    ("!", 0xAB);
    ("?", 0xAC);
    ("…", 0xB0);
    ("‘", 0xB3);
    ("'", 0xB4);
    ("♀", 0xB6);
    ("/", 0xBA);
  ]
  @ List.init 26 (fun i -> (String.make 1 (Char.chr (65 + i)), 0xBB + i))
  @ List.init 26 (fun i -> (String.make 1 (Char.chr (97 + i)), 0xD5 + i))

let name_bytes name =
  let chars = Result.get_ok (Frlg_text.Naming_keyboard.chars name) in
  let coded = List.map (fun c -> List.assoc c charmap) chars in
  coded @ List.init (9 - List.length coded) (fun _ -> 0xFF)

let words (item : Ace_presets.item) =
  let bytes = Array.of_list (List.concat_map name_bytes item.names) in
  List.init
    (Array.length bytes / 4)
    (fun i ->
      let b k = bytes.((4 * i) + k) in
      b 0 lor (b 1 lsl 8) lor (b 2 lsl 16) lor (b 3 lsl 24))

let rotated w =
  let r = 2 * ((w lsr 8) land 0xF) and v = w land 0xFF in
  (v lsr r) lor (v lsl (32 - r)) land 0xFFFFFFFF

let exit_words = [ 0xE3C000FF; 0xE3E3C3C2; 0xE2ECFFE6 ]

(* r11 through the AL words, the halfword stores of r11 by r12, and the AL
   words from the first exit word on. *)
let run_code item =
  let step (r11, stores, tail) w =
    let field s n = (w lsr s) land ((1 lsl n) - 1) in
    if tail <> [] || List.mem w exit_words then (r11, stores, tail @ [ w ])
    else if field 28 4 <> 0xE then (r11, stores, tail)
    else if field 25 3 = 1 && field 12 4 = 11 then
      match field 21 4 with
      | 13 -> (rotated w, stores, tail)
      | 5 -> (r11 + rotated w, stores, tail)
      | op -> failwith (Printf.sprintf "op %d on r11: %08x" op w)
    else if w land 0x0FFFF0F0 = 0x01CCB0B0 then
      ( r11,
        stores @ [ (field 0 4 lor (field 8 4 lsl 4), r11 land 0xFFFF) ],
        tail )
    else (r11, stores, tail)
  in
  let _, stores, tail = List.fold_left step (0, [], []) (words item) in
  (stores, List.filter (fun w -> w lsr 28 = 0xE) tail)

let show_code (item : Ace_presets.item) =
  let stores, tail = run_code item in
  String.concat ", "
    (List.map (fun (off, v) -> Printf.sprintf "+0x%X <- %d" off v) stores)
  ^ if tail = exit_words then "; exits" else "; no exit"

let bad json =
  match Ace_presets.parse (Yojson.Safe.from_string json) with
  | Ok _ -> "parsed"
  | Error e -> e

let item_json boxes =
  Printf.sprintf
    {|{"codes": {"c": {"boxes": {%s}, "item_boxes": [14]}}, "items": {"x": {"code": "c", "id": 1, "boxes": {"14": "A"}}}}|}
    boxes

let thirteen =
  String.concat ", "
    (List.init 13 (fun i -> Printf.sprintf {|"%d": "A"|} (i + 1)))

let case name input expectation = { Table_test.name; input; expectation }
let item slug = Option.get (Ace_presets.find table slug)

let () =
  Table_test.run "ace_presets"
    [
      case "the table's items"
        (fun () -> String.concat ", " (Ace_presets.slugs table))
        "master-ball, luxury-ball, rare-candy";
      case "Master Ball: 999, then item 1"
        (fun () -> show_code (item "master-ball"))
        "+0xC6 <- 999, +0xC4 <- 1; exits";
      case "Luxury Ball: 999, then item 11"
        (fun () -> show_code (item "luxury-ball"))
        "+0xC6 <- 999, +0xC4 <- 11; exits";
      case "Rare Candy: 999, then item 68"
        (fun () -> show_code (item "rare-candy"))
        "+0xC6 <- 999, +0xC4 <- 68; exits";
      case "every item stores its own id"
        (fun () ->
          List.filter
            (fun (i : Ace_presets.item) ->
              fst (run_code i) <> [ (0xC6, 999); (0xC4, i.id) ])
            table.items
          |> List.map (fun (i : Ace_presets.item) -> i.slug)
          |> String.concat ", ")
        "";
      case "names Box 5 to 8 by item"
        (fun () -> String.concat " | " (Ace_presets.known_names table 5))
        "BOX5 | G……o | J……o | Q……o";
      case "boxes 12 to 14 named A"
        (fun () -> Ace_presets.box_name (item "luxury-ball") 13)
        "A";
      case "a table that names a box twice"
        (fun () -> bad (item_json (thirteen ^ {|, "14": "B"|})))
        "ace_presets.json: items.x.the code and the item do not name Boxes 1 \
         to 14 once each.";
      case "a name too long"
        (fun () ->
          bad
            (item_json
               ({|"1": "ABCDEFGHI", |}
               ^ String.concat ", "
                   (List.init 12 (fun i -> Printf.sprintf {|"%d": "A"|} (i + 2)))
               )))
        "ace_presets.json: items.x.Box 1: \"ABCDEFGHI\" is not 1 to 8 \
         characters.";
      case "a character off the keyboard"
        (fun () ->
          bad
            (item_json
               ({|"1": "é", |}
               ^ String.concat ", "
                   (List.init 12 (fun i -> Printf.sprintf {|"%d": "A"|} (i + 2)))
               )))
        "ace_presets.json: items.x.Box 1: the keyboard has no \"é\"";
    ]
