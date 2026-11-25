(* The ACE setup's readers (Easy_chat_screen, Pc_box_screen) on native mGBA
   frames of frlg.ace_setup (2026-11-25): the mail editor's group grid and
   word lists while typing BULK UP / CAPABLE / KARATE CHOP / MAGIKARP, and
   MOVE POKéMON's box screen on Box 1 and Box 3, before and after. The
   fixtures are probe_images output (regen_fixtures.sh ace, from ace.mgba.map);
   the shifted fixture holds every frame at brightness x0.9 and x1.1, each
   channel +-12 and in grey 10 levels (dev/reader_fixtures/shift_frame.py), and
   each must read the same. The image's name says what it shows. *)

open Frlg_readers

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let cell = function
  | None -> "none"
  | Some (c : Easy_chat_screen.cell) -> Printf.sprintf "r%dc%d" c.row c.col

let flag = function None -> "?" | Some true -> "y" | Some false -> "n"

(* Easy Chat frames report the two cursors, box frames the box screen. *)
let read image m =
  if
    String.starts_with ~prefix:"e_" image
    || String.starts_with ~prefix:"g" image
  then
    Printf.sprintf "group %s, word %s"
      (cell (Easy_chat_screen.group_cell m))
      (cell (Easy_chat_screen.word_cell m))
  else
    Printf.sprintf "panel %s, first slot %s, desert %s, forest %s, male %s"
      (flag (Pc_box_screen.panel_occupied m))
      (flag (Pc_box_screen.hand_on_first_slot m))
      (flag (Pc_box_screen.desert_wallpaper m))
      (flag (Pc_box_screen.forest_wallpaper m))
      (if Pc_box_screen.panel_occupied m = Some true then
         flag (Pc_box_screen.male m)
       else "-")

(* Grid rows and list rows are the rows shown: MOVE 1 (grid row 9) and
   BULK UP (list row 11) sit on the bottom row once scrolled to. The male
   mark is read only on an occupied slot. *)
let expected =
  [
    ("g0", "group r0c0, word none");
    ("e_g_actions", "group r3c1, word none");
    ("e_g_move1", "group r3c0, word none");
    ("e_g_move2", "group r3c1, word none");
    ("e_g_pokemon", "group r0c0, word none");
    ("e_w_bulkup", "group none, word r3c0");
    ("e_w_capable", "group none, word r3c1");
    ("e_w_karate", "group none, word r3c0");
    ("e_w_magikarp", "group none, word r3c0");
    ("e_f1", "group none, word none");
    ("b1", "panel n, first slot y, desert n, forest y, male -");
    ("b6", "panel n, first slot n, desert y, forest n, male -");
    ("z7", "panel n, first slot n, desert y, forest n, male -");
    ("z8", "panel y, first slot n, desert y, forest n, male y");
  ]

let base image = Filename.remove_extension (Filename.basename image)

let cases label images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s: %s" label image;
        input = (fun () -> read (base image) (measurements probes));
        expectation =
          Option.value (List.assoc_opt (base image) expected) ~default:"?";
      })
    images

let () =
  Table_test.run "ace readers"
    (cases "mgba" (Wire.read_image_probes "fixtures/ace.mgba.probes.jsonl")
    @ cases "mgba shifted"
        (Wire.read_image_probes "fixtures/ace.mgba.shifted.probes.jsonl"))
