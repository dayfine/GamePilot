(* Pokémon HOME's readers (Home_menus, Home_tile, Box_view) on console B's
   captures (images/, 2026-11-24; and of 2026-11-25: the Switch's HOME after
   PLZA's gifts, boxes 158, 159, 164 and 167 for the digits; the whole frame),
   redacted to what the readers probe (images/README.md), and on each capture
   with its colors shifted as another capture card might show them
   (fixtures/home.shifted.probes.jsonl, regen_fixture.sh), named
   <shift>/<image>: each must read as the capture itself does. One case per
   reader and capture. *)

open Pokemon_home
module B = Box_view

let fixtures = Wire.read_image_probes "home.probes.jsonl"
let shifted = Wire.read_image_probes "home.shifted.probes.jsonl"
let frame probes : Wire.frame = { seq = 1; t_ms = 0.; probes }
let tile_text (t : Home_menus.tile) = Printf.sprintf "(%d, %d)" t.row t.col

(* Each reader's text for a frame. *)
let main_menu m = if Home_menus.main_menu m then "main menu" else "no main menu"

let banner m =
  match Home_menus.banner m with
  | No_banner -> "no banner"
  | b -> Home_menus.banner_to_string b

let game_list m =
  match (Home_menus.cursor_tile m, Home_menus.game_tile m) with
  | None, None -> "no game list"
  | cursor, game ->
      Printf.sprintf "cursor %s, the game's icon %s"
        (Option.fold ~none:"none" ~some:tile_text cursor)
        (Option.fold ~none:"none" ~some:tile_text game)

let home_tile m =
  match Home_tile.tile m with
  | None -> "no HOME tile"
  | Some k ->
      Printf.sprintf "HOME's tile %d%s" k
        (if Home_tile.on_home_tile m then ", the cursor on it" else "")

let slot pane row col : B.slot = { pane; row; col }

let pane_text m pane =
  String.concat "/"
    (List.init B.slot_rows (fun row ->
         String.init B.columns (fun col ->
             if B.empty m (slot pane row col) then '.' else 'x')))

let cursors =
  [ slot Home_box 0 0; slot Home_box 3 5; slot Game_box 0 0; slot Game_box 0 1 ]

let boxes m =
  if not (B.shown m) then "no boxes"
  else
    String.concat "; "
      [
        "box " ^ Option.fold ~none:"unread" ~some:string_of_int (B.number m);
        "home " ^ pane_text m Home_box;
        "game row 1 " ^ String.sub (pane_text m Game_box) 0 B.columns;
        "cursor "
        ^ String.concat " "
            (List.map B.slot_to_string (List.filter (B.cursor_at m) cursors));
      ]

let readers =
  [
    ("main menu", main_menu);
    ("banner", banner);
    ("game list", game_list);
    ("HOME tile", home_tile);
    ("boxes", boxes);
  ]

(* What each capture reads; a reader not named reads nothing. *)
type expected = {
  image : string;
  what : string;
  reads : (string * string) list;  (** reader, its text *)
}

let nothing reader =
  match reader with
  | "main menu" -> "no main menu"
  | "banner" -> "no banner"
  | "game list" -> "no game list"
  | "HOME tile" -> "no HOME tile"
  | _ -> "no boxes"

let box_152_after =
  "box 152; home xxxx../xxxxxx/xxxxxx/xxxxxx/xxx...; game row 1 ......; cursor \
   HOME's box row 4 column 6"

let captures =
  [
    {
      image = "main-menu";
      what = "the main menu";
      reads = [ ("main menu", "main menu") ];
    };
    {
      image = "logging-in";
      what = "logging in";
      reads = [ ("banner", "a two-line banner") ];
    };
    {
      image = "loading-blank-banner";
      what = "the login banner, blank";
      reads = [ ("banner", "a blank banner") ];
    };
    {
      image = "game-select-cursor-on-bdsp";
      what = "the game list, cursor on BDSP, Z-A beside it";
      reads = [ ("game list", "cursor (1, 0), the game's icon (1, 1)") ];
    };
    {
      image = "boxes-152-before-bank-cursor-0-0";
      what = "box 152 before banking, cursor on HOME's first slot";
      reads =
        [
          ( "boxes",
            "box 152; home xxxx../xxxxxx/xxxxxx/xxx.../xxx...; game row 1 \
             xxx...; cursor HOME's box row 1 column 1" );
        ];
    };
    {
      image = "boxes-158-left-paged";
      what = "box 158, paged with R";
      reads =
        [
          ( "boxes",
            "box 158; home ....../....../....../....../......; game row 1 \
             xx....; cursor HOME's box row 1 column 1" );
        ];
    };
    {
      image = "boxes-159-left-paged";
      what = "box 159";
      reads =
        [
          ( "boxes",
            "box 159; home ....../....../....../....../......; game row 1 \
             xx....; cursor HOME's box row 1 column 1" );
        ];
    };
    {
      image = "boxes-164-left-paged";
      what = "box 164";
      reads =
        [
          ( "boxes",
            "box 164; home xx..../xx..../xx..../xx..../x.....; game row 1 \
             xx....; cursor HOME's box row 1 column 1" );
        ];
    };
    {
      image = "boxes-167-left-paged";
      what = "box 167";
      reads =
        [
          ( "boxes",
            "box 167; home xx.xxx/xx.xxx/xx..xx/xx..xx/xx..xx; game row 1 \
             xx....; cursor HOME's box row 1 column 1" );
        ];
    };
    {
      image = "boxes-152-after-bank";
      what = "box 152 after banking: three more in HOME's, the game's emptied";
      reads = [ ("boxes", box_152_after) ];
    };
    {
      image = "boxes-saving";
      what = "saving: its two lines over the boxes";
      reads = [ ("banner", "a two-line banner"); ("boxes", box_152_after) ];
    };
    {
      image = "switch-home-cursor-on-pokemon-home";
      what = "the Switch's HOME, cursor on Pokémon HOME";
      reads = [ ("HOME tile", "HOME's tile 0, the cursor on it") ];
    };
    {
      image = "switch-home-pokemon-home-third";
      what = "the Switch's HOME, Pokémon HOME third";
      reads = [ ("HOME tile", "HOME's tile 2") ];
    };
    {
      image = "switch-home-cursor-on-za-home-fifth-cut";
      what = "the Switch's HOME after PLZA closed: HOME the fifth, cut off";
      reads = [];
    };
  ]

let probes_of image = List.assoc ("./" ^ image ^ ".png") fixtures

let expected_of c reader =
  Option.value ~default:(nothing reader) (List.assoc_opt reader c.reads)

let capture_cases =
  List.concat_map
    (fun c ->
      List.map
        (fun (reader, read) : Table_test.case ->
          {
            name = Printf.sprintf "%s: %s" c.what reader;
            input = (fun () -> read (frame (probes_of c.image)));
            expectation = expected_of c reader;
          })
        readers)
    captures

let unshifted image =
  match String.split_on_char '/' image with
  | [ "."; _; file ] -> "./" ^ file
  | _ -> failwith ("no shift in " ^ image)

let shifted_cases =
  List.concat_map
    (fun (image, probes) ->
      List.map
        (fun (reader, read) : Table_test.case ->
          {
            name = Printf.sprintf "shifted: %s: %s" image reader;
            input = (fun () -> read (frame probes));
            expectation = read (frame (List.assoc (unshifted image) fixtures));
          })
        readers)
    shifted

let () = Table_test.run "home_readers" (capture_cases @ shifted_cases)
