(* The ACE setup's readers (Easy_chat_screen, Pc_box_screen) on native mGBA
   frames of frlg.ace_setup (2026-11-25): the mail editor's group grid and
   word lists while typing BULK UP / CAPABLE / KARATE CHOP / MAGIKARP, and
   MOVE POKéMON's box screen on Box 1 and Box 3, before and after, and
   WITHDRAW's on Box 1 with MIMIEN (holding an Antidote) and a Magikarp
   (holding nothing) under the hand. The
   fixtures are probe_images output (regen_fixtures.sh ace, from ace.mgba.map);
   the shifted fixture holds every frame at brightness x0.9 and x1.1, each
   channel +-12 and in grey 10 levels (dev/reader_fixtures/shift_frame.py), and
   each must read the same. The image's name says what it shows: e_g_ the
   editor's group grid, e_w_ a word list, e_fields_ the message's fields,
   box1_/box3_ the box screen (the title's wallpaper for Box 1, Ace_mail's
   Forest). The wall_<wallpaper>_ frames are box titles
   read for their wallpaper (Pc_box_screen.title_wallpaper), <wallpaper> what
   it must read ("none" for the twelve a player can pick besides the four
   defaults): on mGBA all sixteen wallpapers (box-titles/, Boxes 1-14, some
   changed by hand) and three box screens with the hand on the title, the
   ACE Pokémon or an empty slot (ace-setup/); on the Switch Boxes 1-14 as a
   new game leaves them (console B, box-titles-20261125/: the title bar
   only, the rest grey), each shifted too.

   Headroom on these frames and their shifted versions (threshold; worst
   reading on the thing; worst off it):
   - group rectangle, red share of the edge box: 0.15; 0.25; 0.
   - word arrow, dark share (Cursor_column): 0.10; 0.136; 0.
   - PKMN DATA, sum of channel stddevs: 10; 157; 0.
   - PKMN DATA's item line, the same: 10; 180 (grey); 0.
   - hand shadow on slot 1, share: 0.25; 0.31 (grey); 0.
   - Desert wallpaper, r-g / g-b: 15 / 20; 29 / 38; -60.
   - male mark, blue share: 0.15; 0.231 (male, all shifts); 0 (female and empty
     panels, all shifts).
   - title wallpaper, the farther of the sky's and the ground's distance from
     the wallpaper's colours: 50; 40 (Savanna, mGBA x0.9); 60 (Pokémon
     Center's against Forest, green +12).
   - box screen (Pc_screen.box_screen_shown, its own thresholds): read on
     every mGBA frame, shifted too, but with a Pokémon under the hand.
   The word arrow and the hand shadow are the thin ones; the actions confirm
   both by a second read (the row's words, the panel). *)

open Frlg_readers

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let cell = function
  | None -> "none"
  | Some (c : Easy_chat_screen.cell) -> Printf.sprintf "r%dc%d" c.row c.col

let flag = function None -> "?" | Some true -> "y" | Some false -> "n"

let wallpaper m =
  Option.fold ~none:"none"
    ~some:(fun w -> String.lowercase_ascii (Pc_box_screen.wallpaper_name w))
    (Pc_box_screen.title_wallpaper m)

(* Pc_screen.box_screen_shown, which Ace_code reads beside the title's
   wallpaper: the PKMN DATA panel's lilac edge, hidden by a Pokémon's picture
   when the hand is over one ([on_a_pokemon]: "no box"). The Switch's
   box-title frames show the title bar only, the rest grey: not read
   there. *)
let box_screen image m =
  if Strings.Contains.substring image "_switch_" then "-"
  else if Pc_screen.box_screen_shown m then "box screen"
  else "no box"

let on_a_pokemon =
  [
    "wall_desert_box3_ace_on_first_slot";
    "wall_desert_desert_box03_hand_on_first_slot";
  ]

(* Easy Chat frames report the two cursors, wall_ frames the title's
   wallpaper, box frames the box screen. *)
let read image m =
  if String.starts_with ~prefix:"wall_" image then
    Printf.sprintf "%s, wallpaper %s" (box_screen image m) (wallpaper m)
  else if String.starts_with ~prefix:"e_" image then
    Printf.sprintf "group %s, word %s"
      (cell (Easy_chat_screen.group_cell m))
      (cell (Easy_chat_screen.word_cell m))
  else
    Printf.sprintf
      "%s, panel %s, item %s, first slot %s, desert %s, title %s, male %s"
      (box_screen image m)
      (flag (Pc_box_screen.panel_occupied m))
      (flag (Pc_box_screen.holds_item m))
      (flag (Pc_box_screen.hand_on_first_slot m))
      (flag (Pc_box_screen.desert_wallpaper m))
      (wallpaper m)
      (flag (Pc_box_screen.male m))

(* Grid rows and list rows are the rows shown: MOVE 1 (grid row 9) and
   BULK UP (list row 11) sit on the bottom row once scrolled to. The withdraw
   frames' MIMIEN is male and Magikarp is female; empty panels read not male
   (#194). *)
let expected =
  [
    ("e_g_first_open", "group r0c0, word none");
    ("e_g_actions", "group r3c1, word none");
    ("e_g_move1", "group r3c0, word none");
    ("e_g_move2", "group r3c1, word none");
    ("e_g_pokemon", "group r0c0, word none");
    ("e_w_bulkup", "group none, word r3c0");
    ("e_w_capable", "group none, word r3c1");
    ("e_w_karate", "group none, word r3c0");
    ("e_w_magikarp", "group none, word r3c0");
    ("e_fields_after_bulk_up", "group none, word none");
    ( "box1_hand_on_empty_first_slot",
      "box screen, panel n, item n, first slot y, desert n, title forest, male \
       n" );
    ( "box3_hand_on_third_slot",
      "box screen, panel n, item n, first slot n, desert y, title desert, male \
       n" );
    ( "box3_ace_hand_on_title",
      "box screen, panel n, item n, first slot n, desert y, title desert, male \
       n" );
    ( "box3_ace_on_first_slot",
      "no box, panel y, item y, first slot n, desert y, title desert, male y" );
    ( "box1_withdraw_menu_mimien_antidote",
      "box screen, panel y, item y, first slot n, desert n, title none, male y"
    );
    ( "box1_withdraw_menu_magikarp",
      "box screen, panel y, item n, first slot n, desert n, title none, male n"
    );
  ]

let base image = Filename.remove_extension (Filename.basename image)

(* A wall_ frame's wallpaper is in its name. *)
let expectation image =
  match String.split_on_char '_' image with
  | "wall" :: want :: _ ->
      let box =
        if Strings.Contains.substring image "_switch_" then "-"
        else if List.mem image on_a_pokemon then "no box"
        else "box screen"
      in
      Printf.sprintf "%s, wallpaper %s" box want
  | _ -> Option.value (List.assoc_opt image expected) ~default:"?"

let cases label images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s: %s" label image;
        input = (fun () -> read (base image) (measurements probes));
        expectation = expectation (base image);
      })
    images

let () =
  Table_test.run "ace readers"
    (cases "mgba" (Wire.read_image_probes "fixtures/ace.mgba.probes.jsonl")
    @ cases "mgba shifted"
        (Wire.read_image_probes "fixtures/ace.mgba.shifted.probes.jsonl")
    @ cases "switch" (Wire.read_image_probes "fixtures/ace.switch.probes.jsonl")
    @ cases "switch shifted"
        (Wire.read_image_probes "fixtures/ace.switch.shifted.probes.jsonl"))
