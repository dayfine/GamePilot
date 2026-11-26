(* Gift_boxes.settle on a scripted console: the main menu and the Boxes as
   console B showed them (2026-11-20 to 26), each frame the probes of a real
   capture (../../../readers/test/fixtures/gifts/gifts.probes.jsonl): the
   menu tutorial-cards' it-menu-no-card (five cards, an empty sixth; the
   first card's bar copied to the sixth for a Pokémon in party slot 6), the
   Boxes with a Pokémon under the cursor console B's Box 8 with Xerneas
   (mystery-gift/boxes-box-8-ja-360p), an empty cell the fork's
   box-cells/empty-2-5-360p. The box title's band is console B's: Box 1's
   from mystery-gift/boxes-box-1-ja-360p, every other box's Box 8's.

   The console keeps console B's 8 boxes of 30 cells and the party's slot 6;
   the Boxes open on the box last looked at, the cursor on its first slot;
   the d-pad moves the cursor (rows 0, the party, to 5), L and R the box,
   round from Box 1 to Box 8 and back; Y picks a Pokémon up, drops it on an
   empty cell or swaps it with the one there; B leaves to the menu. Nothing
   reaches a daemon. *)

module Gb = Plza_claim_gifts.Gift_boxes
module C = Plza_gift_catalog.Gift_catalog

let captures =
  Wire.read_image_probes
    "../../../readers/test/fixtures/gifts/gifts.probes.jsonl"

let capture path = List.assoc path captures
let menu_frame = capture "./tutorial-cards/it-menu-no-card.jpg"
let filled_frame = capture "./mystery-gift/boxes-box-8-ja-360p.png"
let empty_frame = capture "./box-cells/empty-2-5-360p.png"
let band frame = List.assoc "box_title.band" frame
let box_one_band = band (capture "./mystery-gift/boxes-box-1-ja-360p.png")
let other_band = band filled_frame
let box_count = 8
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
  named_one : bool;  (** Box 1's title reads as Box 1 (not renamed). *)
  mutable t_ms : float;
  mutable seq : int;
  mutable presses : string list;
}

let share x = Wire.Color_count { fraction = x; mean = None }

let set shares probes =
  List.map
    (fun (id, p) -> (id, Option.value ~default:p (List.assoc_opt id shares)))
    probes

let title c =
  ( "box_title.band",
    if c.box = 0 && c.named_one then box_one_band else other_band )

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
        set [ title c ] (if cell_filled c then filled_frame else empty_frame)
  in
  { seq = c.seq; t_ms = c.t_ms; probes }

let set_cell c v =
  if c.row = 0 then c.party_six <- v
  else c.boxes.(c.box).(((c.row - 1) * 6) + c.col) <- v

let clamp lo hi v = max lo (min hi v)
let page c step = c.box <- (c.box + step + box_count) mod box_count

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
let console ?(named_one = true) ?(party_six = false) ~last_box filled =
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
    named_one;
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

let settle c slots =
  match
    on_console c (fun () -> Gb.settle ~log:ignore (List.map slot slots))
  with
  | Ok { reads; moved } ->
      Printf.sprintf "%s | moved %b | %s | %s" (where c) moved
        (String.concat ", "
           (List.map
              (fun ((s : C.box_slot), r) ->
                Printf.sprintf "slot %d %s" s.slot (read_text r))
              reads))
        (match c.screen with Menu _ -> "main menu" | Boxes -> "Boxes")
  | Error e -> "error: " ^ e

(* The presses, run together ("A Down Down L L"). *)
let presses c () =
  ignore (settle c [ 1; 2 ]);
  String.concat " " c.presses

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "gift_boxes"
    [
      case "party of five, Boxes last on Box 8: nothing to move"
        (fun () -> settle (console ~last_box:8 []) [ 1; 2 ])
        "Box 1: - | moved false | slot 1 empty, slot 2 empty | main menu";
      case "party of five, Boxes last on Box 8: the presses"
        (presses (console ~last_box:8 []))
        "Down Down Down A Down L L L L L L L Up Right B";
      case "a gift in party slot 6: moved to the first empty slot"
        (fun () -> settle (console ~party_six:true ~last_box:8 []) [ 1; 2 ])
        "Box 1: 1 | moved true | slot 1 filled, slot 2 empty | main menu";
      case "a gift in party slot 6, the first slot taken: to the second"
        (fun () ->
          settle (console ~party_six:true ~last_box:8 [ (1, 1) ]) [ 1; 2 ])
        "Box 1: 1 2 | moved true | slot 1 filled, slot 2 filled | main menu";
      case "a gift in party slot 6: the presses"
        (presses (console ~party_six:true ~last_box:8 []))
        "Down Down Down A Down L L L L L L L Up Right Up Right Right Right \
         Right Y Down Left Left Left Left Left Y Right B";
      case "the Boxes open on Box 1: no L"
        (presses (console ~last_box:1 [ (1, 1); (1, 2) ]))
        "Down Down Down A Down Up Right B";
      case "party slot 6 and both slots full: not moved"
        (fun () ->
          settle
            (console ~party_six:true ~last_box:3 [ (1, 1); (1, 2) ])
            [ 1; 2 ])
        "Box 1: 1 2; party 6 | moved false | slot 1 filled, slot 2 filled | \
         main menu";
      case "no box titled Box 1: nothing moved"
        (fun () ->
          let c = console ~named_one:false ~party_six:true ~last_box:8 [] in
          let r = settle c [ 1 ] in
          r ^ " | " ^ string_of_bool c.party_six)
        "error: no Box 1 title after 32 L (glyphs 6 3 6 3 15 24 25 15) | true";
      case "a slot outside Box 1 is not read"
        (fun () ->
          let c = console ~last_box:1 [] in
          match
            on_console c (fun () ->
                Gb.settle ~log:ignore [ { box = 2; slot = 1 } ])
          with
          | Ok { reads = [ (_, r) ]; _ } -> read_text r
          | Ok _ -> "other reads"
          | Error e -> "error: " ^ e)
        "not read: only Box 1 is read";
    ]
