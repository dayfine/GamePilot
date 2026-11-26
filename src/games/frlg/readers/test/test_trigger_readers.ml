(* The ACE trigger's and the item storage's readers (Pc_box_screen.hand_quick,
   Item_pc_screen) on native mGBA frames (2026-11-25): MOVE POKéMON's Box 3
   (Desert, 0x0351 in slot 1) through the double swap, the hand normal, quick
   (orange) and holding; and PLAYER'S PC's item storage: its menus, WITHDRAW
   ITEM's list at the top, scrolled and at CANCEL, the item's menu, the
   quantity box and the "Withdrew" message. The fixtures are probe_images
   output (regen_fixtures.sh trigger, from trigger.mgba.map); the shifted
   fixture holds every frame at brightness x0.9 and x1.1, each channel +-12
   and in grey 10 levels (dev/reader_fixtures/shift_frame.py), and each must
   read the same. This test prints the headroom (worst share on the thing,
   worst off it) of each colour reader. *)

open Frlg_readers

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }
let flag = function None -> "?" | Some true -> "y" | Some false -> "n"
let row = function None -> "-" | Some r -> string_of_int r

(* The image's name: ace-trigger_<what>, item-storage_<what>. *)
let base image = Filename.remove_extension (Filename.basename image)

(* The hand is read on the first slot only: [hand_slot2], [holding_slot2]
   and [swap2] have it on slot 2, where the box shows 0x0351's icon, whose
   colours brightened x1.1 reach the glove's yellow: not read. *)
let off_first_slot image =
  List.mem image
    [
      "ace-trigger_hand_slot2"; "ace-trigger_holding_slot2"; "ace-trigger_swap2";
    ]

let read image m =
  if String.starts_with ~prefix:"ace-trigger_" image then
    if off_first_slot image then "quick -"
    else Printf.sprintf "quick %s" (flag (Pc_box_screen.hand_quick m))
  else
    Printf.sprintf "storage %s, cursor %s, quantity %s"
      (flag (Item_pc_screen.shown m))
      (row (Item_pc_screen.cursor_row m))
      (flag (Item_pc_screen.quantity_shown m))

let expected =
  [
    ("ace-trigger_hand_slot1", "quick n");
    ("ace-trigger_hand_slot1_b", "quick n");
    ("ace-trigger_orange_slot1", "quick y");
    ("ace-trigger_orange_slot1_b", "quick y");
    ("ace-trigger_holding_slot1", "quick y");
    ("ace-trigger_put_down", "quick y");
    ("ace-trigger_normal_again", "quick n");
    ("ace-trigger_hand_slot2", "quick -");
    ("ace-trigger_holding_slot2", "quick -");
    ("ace-trigger_swap2", "quick -");
    ("item-storage_pc_list", "storage n, cursor -, quantity n");
    ("item-storage_player_pc_menu", "storage n, cursor -, quantity n");
    ("item-storage_item_storage_menu", "storage n, cursor -, quantity n");
    ("item-storage_list_code", "storage y, cursor 0, quantity n");
    ("item-storage_list_code_master", "storage y, cursor 1, quantity n");
    ("item-storage_list8_top", "storage y, cursor 0, quantity n");
    ("item-storage_list8_down4", "storage y, cursor 3, quantity n");
    ("item-storage_list8_down8", "storage y, cursor 5, quantity n");
    ("item-storage_list30_top", "storage y, cursor 0, quantity n");
    ("item-storage_list_after", "storage y, cursor 1, quantity n");
    ("item-storage_submenu", "storage y, cursor 1, quantity n");
    ("item-storage_qty_001", "storage y, cursor 1, quantity y");
    ("item-storage_qty_012", "storage y, cursor 1, quantity y");
    ("item-storage_qty_999", "storage y, cursor 1, quantity y");
    ("item-storage_qty_950", "storage y, cursor 1, quantity y");
    ("item-storage_withdrew_msg", "storage y, cursor 1, quantity n");
  ]

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

(* Worst share on and off the thing a share probe looks for, over the
   images [on image] says hold it ([None]: not read there). *)
let headroom images what id on =
  let shares =
    List.filter_map
      (fun (image, probes) ->
        match (on (base image), Color_count.share (measurements probes) id) with
        | Some is_on, Some s -> Some (is_on, s)
        | _ -> None)
      images
  in
  let lo = List.fold_left (fun a (o, s) -> if o then min a s else a) 1. shares
  and hi =
    List.fold_left (fun a (o, s) -> if o then a else max a s) 0. shares
  in
  Printf.printf "headroom %s: worst on %.2f, worst off %.2f\n" what lo hi

let in_expected image f = Option.map f (List.assoc_opt image expected)

let () =
  let frames = Wire.read_image_probes "fixtures/trigger.mgba.probes.jsonl"
  and shifted =
    Wire.read_image_probes "fixtures/trigger.mgba.shifted.probes.jsonl"
  in
  let all = frames @ shifted in
  let has s sub =
    let n = String.length sub in
    let rec go i =
      i + n <= String.length s && (String.sub s i n = sub || go (i + 1))
    in
    go 0
  in
  headroom all "quick hand (yellow share; 0.12)" "pc_box.hand_first_slot"
    (fun image ->
      if
        String.starts_with ~prefix:"ace-trigger_" image
        && not (off_first_slot image)
      then in_expected image (fun e -> e = "quick y")
      else None);
  headroom all "item storage label (orange share; 0.4)" "item_pc.label"
    (fun image -> in_expected image (fun e -> has e "storage y"));
  headroom all "quantity arrow (orange share; 0.12)" "item_pc.quantity"
    (fun image -> in_expected image (fun e -> has e "quantity y"));
  Table_test.run "trigger readers"
    (cases "mgba" frames @ cases "mgba shifted" shifted)
