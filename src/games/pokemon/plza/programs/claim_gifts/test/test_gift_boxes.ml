(* Gift_boxes.arrange on a scripted console: the main menu and the Boxes as
   console B showed them (2026-11-20 to 26), each frame the probes of a real
   capture (../../../readers/test/fixtures/gifts/gifts.probes.jsonl): the
   menu tutorial-cards' it-menu-no-card (five cards, an empty sixth; the
   first card's bar copied to the sixth for a Pokémon in party slot 6), the
   Boxes with a Pokémon under the cursor console B's Box 8 with Xerneas
   (mystery-gift/boxes-box-8-ja-360p), an empty cell the fork's
   box-cells/empty-2-5-360p. The box title's columns are made for the box
   shown: "Box N" inked as wide as the fork's English captures read (64 px
   for one digit, 80 for two, a last "1" 4 px short on the right), centred.

   The console keeps 32 boxes of 30 cells and the party's slot 6; the Boxes
   open on the box last looked at, the cursor on its first slot; the d-pad
   moves the cursor (rows 0, the party, to 5), L and R the box, round from
   Box 1 to Box 32 and back (or not, for a console whose L stops at Box 1); Y
   picks a Pokémon up, drops it on an empty cell or swaps it with the one
   there; B leaves to the menu. Nothing reaches a daemon. *)

module Gb = Plza_claim_gifts.Gift_boxes
module C = Plza_gift_catalog.Gift_catalog

let captures =
  Wire.read_image_probes
    "../../../readers/test/fixtures/gifts/gifts.probes.jsonl"

let capture path = List.assoc path captures
let menu_frame = capture "./tutorial-cards/it-menu-no-card.jpg"
let filled_frame = capture "./mystery-gift/boxes-box-8-ja-360p.png"
let empty_frame = capture "./box-cells/empty-2-5-360p.png"
let box_count = 32
let cells = 30

type screen = Menu of int | Boxes

type console = {
  mutable screen : screen;
  mutable box : int;  (** 0 is Box 1 *)
  mutable row : int;
  mutable col : int;
  mutable held : bool;
  mutable party_six : bool;
  boxes : bool array array;
  wraps : bool;
  mutable t_ms : float;
  mutable seq : int;
  mutable presses : string list;
}

let share x = Wire.Color_count { fraction = x; mean = None }

let set shares probes =
  List.map
    (fun (id, p) -> (id, Option.value ~default:p (List.assoc_opt id shares)))
    probes

(* The title band (320, 336, 290, 34) as 97 columns of a 360p frame, inked
   from [left] to [right]. *)
let title_columns number =
  let one_digit = number < 10 in
  let width = if one_digit then 64 else 80 in
  let left = 442 - (width / 2) in
  let right = left + width - if number mod 10 = 1 then 4 else 0 in
  List.init 97 (fun i ->
      let x = 320 + (i * 290 / 97) in
      if x >= left && x <= right then 0.5 else 0.)

let title number =
  ( "box_title.band",
    Wire.Line_shares
      { rows = List.init 12 (fun _ -> 0.3); columns = title_columns number } )

let cell_filled c =
  if c.row = 0 then c.col < 5 || c.party_six
  else c.boxes.(c.box).(((c.row - 1) * 6) + c.col)

let bands r =
  List.init 6 (fun j ->
      ( Printf.sprintf "main_menu_row.band%d" j,
        share (if j = r then 0.95 else 0.05) ))

let menu_probes c r =
  let card0 = List.assoc "main_menu_row.card0" menu_frame in
  let six = if c.party_six then [ ("main_menu_row.card5", card0) ] else [] in
  set (bands r @ six) menu_frame

let frame c : Effects.measurements =
  c.seq <- c.seq + 1;
  let probes =
    match c.screen with
    | Menu r -> menu_probes c r
    | Boxes ->
        set
          [ title (c.box + 1) ]
          (if cell_filled c then filled_frame else empty_frame)
  in
  { seq = c.seq; t_ms = c.t_ms; probes }

let set_cell c v =
  if c.row = 0 then c.party_six <- v
  else c.boxes.(c.box).(((c.row - 1) * 6) + c.col) <- v

let clamp lo hi v = max lo (min hi v)

let page c step =
  let next = c.box + step in
  if next >= 0 && next < box_count then c.box <- next
  else if c.wraps then c.box <- (next + box_count) mod box_count

(* Y: pick up, drop on an empty cell, or swap (the hand stays full). *)
let y c =
  match (c.held, cell_filled c) with
  | false, true ->
      set_cell c false;
      c.held <- true
  | true, false ->
      set_cell c true;
      c.held <- false
  | _ -> ()

let on_boxes c (b : Wire.button) =
  match b with
  | Up -> c.row <- clamp 0 5 (c.row - 1)
  | Down -> c.row <- clamp 0 5 (c.row + 1)
  | Left -> c.col <- clamp 0 5 (c.col - 1)
  | Right -> c.col <- clamp 0 5 (c.col + 1)
  | L -> page c (-1)
  | R -> page c 1
  | Y -> y c
  | B -> c.screen <- Menu 0
  | _ -> ()

let on_menu c r (b : Wire.button) =
  match b with
  | Down -> c.screen <- Menu ((r + 1) mod 6)
  | Up -> c.screen <- Menu ((r + 5) mod 6)
  | A when r = 0 ->
      c.screen <- Boxes;
      c.row <- 1;
      c.col <- 0
  | _ -> ()

let press c = function
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      List.iter
        (fun b ->
          c.presses <- c.presses @ [ Wire.string_of_button b ];
          match c.screen with Menu r -> on_menu c r b | Boxes -> on_boxes c b)
        buttons;
      c.t_ms <- c.t_ms +. float_of_int (hold_ms + cooldown_ms)
  | Wait { wait_ms } -> c.t_ms <- c.t_ms +. float_of_int wait_ms

let rec await c check timeout_ms start =
  let m = frame c in
  if check m then Effects.Holds m
  else if c.t_ms -. start > float_of_int timeout_ms then Timeout
  else (
    c.t_ms <- c.t_ms +. 50.;
    await c check timeout_ms start)

let on_console c f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          let answer (v : a) =
            Some (fun (k : (a, _) continuation) -> continue k v)
          in
          match e with
          | Effects.Await (check, timeout_ms) ->
              answer (await c check timeout_ms c.t_ms)
          | Effects.Submit commands ->
              List.iter (press c) commands;
              answer { Wire.batch_id = "b"; seq = c.seq; t_ms = c.t_ms }
          | Effects.Read -> answer (Some (frame c))
          | Effects.Now -> answer c.t_ms
          | _ -> None);
    }

(* A console on the main menu's row 3, the Boxes last left on [last_box],
   with Pokémon in the (box, slot) cells given. *)
let console ?(wraps = true) ?(party_six = false) ~last_box filled =
  let boxes = Array.init box_count (fun _ -> Array.make cells false) in
  List.iter (fun (b, s) -> boxes.(b - 1).(s - 1) <- true) filled;
  {
    screen = Menu 3;
    box = last_box - 1;
    row = 1;
    col = 0;
    held = false;
    party_six;
    boxes;
    wraps;
    t_ms = 0.;
    seq = 0;
    presses = [];
  }

let slot n : C.box_slot = { box = 1; slot = n }

let read_text = function
  | Gb.Filled -> "filled"
  | Empty -> "empty"
  | Not_read why -> "not read: " ^ why

(* Where the Pokémon are after the run, and what it said. *)
let where c =
  let filled b =
    List.filter_map
      (fun s ->
        if c.boxes.(b - 1).(s - 1) then Some (string_of_int s) else None)
      (List.init cells (fun s -> s + 1))
  in
  let others =
    List.filter_map
      (fun b ->
        match filled b with
        | [] -> None
        | ss -> Some (Printf.sprintf "Box %d: %s" b (String.concat " " ss)))
      (List.init (box_count - 1) (fun b -> b + 2))
  in
  String.concat "; "
    (("Box 1: " ^ match filled 1 with [] -> "-" | ss -> String.concat " " ss)
     :: (if c.party_six then [ "party 6" ] else [])
    @ others)

let arrange c slots =
  match
    on_console c (fun () -> Gb.arrange ~log:ignore (List.map slot slots))
  with
  | Ok { reads; moved } ->
      Printf.sprintf "%s | moved %d | %s | %s" (where c) moved
        (String.concat ", "
           (List.map
              (fun ((s : C.box_slot), r) ->
                Printf.sprintf "slot %d %s" s.slot (read_text r))
              reads))
        (match c.screen with Menu _ -> "main menu" | Boxes -> "Boxes")
  | Error e -> "error: " ^ e

let count b c = List.length (List.filter (( = ) b) c.presses)

let ys c () =
  ignore (arrange c [ 2; 1 ]);
  Printf.sprintf "%d Y, %d L, %d R" (count "Y" c) (count "L" c) (count "R" c)

let case name input expectation : Table_test.case = { name; input; expectation }

(* Console B after the runs of 2026-11-25 and -26: Vivillon in party slot 6,
   Xerneas in Box 8 slot 1, the Boxes last on Box 8. *)
let console_b () = console ~party_six:true ~last_box:8 [ (8, 1) ]

let () =
  Table_test.run "gift_boxes"
    [
      case "console B: Vivillon from party slot 6, Xerneas from Box 8"
        (fun () -> arrange (console_b ()) [ 2; 1 ])
        "Box 1: 1 2 | moved 2 | slot 2 filled, slot 1 filled | main menu";
      case "console B: Box 8 and party slot 6 emptied"
        (fun () ->
          let c = console_b () in
          ignore (arrange c [ 2; 1 ]);
          string_of_bool (c.party_six || c.boxes.(7).(0)))
        "false";
      case "console B: the presses' count" (ys (console_b ())) "6 Y, 15 L, 8 R";
      case "a gift landed in the last-viewed Box 8, party slot 6 empty"
        (fun () -> arrange (console ~last_box:8 [ (8, 1) ]) [ 1 ])
        "Box 1: 1 | moved 1 | slot 1 filled | main menu";
      case "a gift in party slot 6 from an earlier run"
        (fun () -> arrange (console ~party_six:true ~last_box:1 []) [ 2 ])
        "Box 1: 2 | moved 1 | slot 2 filled | main menu";
      case "already in place: nothing moved"
        (fun () -> arrange (console ~last_box:8 [ (1, 1); (1, 2) ]) [ 2; 1 ])
        "Box 1: 1 2 | moved 0 | slot 2 filled, slot 1 filled | main menu";
      case "already in place: no Y"
        (ys (console ~last_box:8 [ (1, 1); (1, 2) ]))
        "0 Y, 8 L, 1 R";
      case "the Boxes open on Box 1: found in place"
        (fun () -> arrange (console ~last_box:1 [ (1, 1) ]) [ 1 ])
        "Box 1: 1 | moved 0 | slot 1 filled | main menu";
      case "the Boxes open on Box 12: back over the two-digit boxes"
        (fun () -> arrange (console ~last_box:12 [ (12, 3) ]) [ 1 ])
        "Box 1: 1 | moved 1 | slot 1 filled | main menu";
      case "not found anywhere: its slot reads empty"
        (fun () -> arrange (console ~last_box:8 []) [ 1 ])
        "Box 1: - | moved 0 | slot 1 empty | main menu";
      case "the open box holds a Pokémon of the player's too: none moved"
        (fun () -> arrange (console ~last_box:8 [ (8, 1); (8, 5) ]) [ 1 ])
        "Box 1: -; Box 8: 1 5 | moved 0 | slot 1 empty | main menu";
      case "L stops at Box 1: no box title widens"
        (fun () -> arrange (console ~wraps:false ~last_box:8 [ (8, 1) ]) [ 1 ])
        "error: no box title widened in 40 L";
      case "a slot outside Box 1 is not arranged"
        (fun () ->
          let c = console ~last_box:1 [] in
          match
            on_console c (fun () ->
                Gb.arrange ~log:ignore [ { box = 2; slot = 1 } ])
          with
          | Ok { reads = [ (_, r) ]; _ } -> read_text r
          | Ok _ -> "other reads"
          | Error e -> "error: " ^ e)
        "not read: only Box 1 is arranged";
    ]
