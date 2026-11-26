(* Gift_claim.claim of the Internet gift (Vivillon) and Save_progress.save
   on a scripted console: a
   screen that changes with each press as console B's did (2026-11-25), shown
   as frames 50 ms apart, each one the probes of a real capture
   (../../../readers/test/fixtures/gifts/gifts.probes.jsonl, every gift
   probe, the gift's name matched by its English template) with the menu's
   highlighted row or the list's cursor set. The main menu is
   tutorial-cards' it-menu-no-card; the list console B's English one
   (Vivillon item 4) or its French one (no item matches the English name, as
   on the Japanese game's run of 2026-11-25); the card Vivillon's; every
   other screen (Link Play, the Mystery Gift menu, the Yes/No questions) the
   white fade before a card, which no reader knows. The SAVE dialog is console
   B's at 18:16 before the save and its copy at 18:18 after, its "Last Saved"
   shares changed a little on every frame, as a capture's do. Nothing
   reaches a daemon.

   The list must count once it has shown for 1 s, though no two of its
   frames are equal; and a gift not found on the list must leave it with B
   and yes to "stop receiving?" (B alone only opens and cancels that
   question) and then the link, back on the main menu. The SAVE dialog's
   "Last Saved" must count once it has shown for 1 s, though its shares
   differ on every frame. *)

module Gc = Plza_claim_gifts.Gift_claim
module G = Plza_claim_gifts.Mystery_gift
module Sp = Plza_claim_gifts.Save_progress

let gift =
  List.hd
    (Result.get_ok
       (Plza_gift_catalog.Gift_catalog_decode.of_json
          (Yojson.Safe.from_file "../../../gift_catalog/gifts.json")))

let captures =
  Wire.read_image_probes
    "../../../readers/test/fixtures/gifts/gifts.probes.jsonl"

let capture path = List.assoc path captures
let menu_frame = capture "./tutorial-cards/it-menu-no-card.jpg"
let english_list = capture "./mystery-gift/gift-list-cursor-on-1.png"
let french_list = capture "./mystery-gift/gift-list-fr-cursor-on-1.png"
let card_frame = capture "./mystery-gift/card-vivillon.png"
let other_frame = capture "./mystery-gift/claim-white-fade.png"
let before_save = capture "./mystery-gift/save-dialog-last-saved-1816.png"

let after_save =
  capture "./mystery-gift/synthetic-save-dialog-last-saved-1818.png"

type screen =
  | Menu of int
  | Link_play
  | Gift_menu
  | Connecting
  | Gift_list of int
  | Stop_receiving of int
  | Card
  | Disconnect
  | Disconnected
  | Save_dialog of int
  | Saving of int

let rows = 6
let last_item = 3

(* The screen after a press, as on the console. *)
let next screen (button : Wire.button) =
  match (screen, button) with
  | Menu r, Down -> Menu ((r + 1) mod rows)
  | Menu r, Up -> Menu ((r + rows - 1) mod rows)
  | Menu 5, A -> Link_play
  | Menu r, R -> Save_dialog r
  | Save_dialog r, A -> Saving r
  | Save_dialog r, B -> Menu r
  | Saving r, A -> Menu r
  | Link_play, A -> Gift_menu
  | Link_play, B -> Menu 5
  | Gift_menu, A -> Connecting
  | Gift_menu, B -> Disconnect
  | Connecting, A -> Gift_list 0
  | Gift_list c, Down -> Gift_list (min last_item (c + 1))
  | Gift_list _, A -> Card
  | Gift_list c, B -> Stop_receiving c
  | Stop_receiving _, A -> Gift_menu
  | Stop_receiving c, B -> Gift_list c
  | Card, A -> Gift_list last_item
  | Disconnect, A -> Disconnected
  | Disconnect, B -> Gift_menu
  | Disconnected, A -> Link_play
  | s, _ -> s

let share x = Wire.Color_count { fraction = x; mean = None }

let set shares probes =
  List.map
    (fun (id, p) -> (id, Option.value ~default:p (List.assoc_opt id shares)))
    probes

let lit prefix k =
  List.init rows (fun j ->
      (Printf.sprintf "%s%d" prefix j, share (if j = k then 0.95 else 0.05)))

(* "Last Saved"'s shares moved by up to 0.002 each, by frame. *)
let jitter seq probes =
  List.map
    (fun (id, p) ->
      match p with
      | Wire.Line_shares { rows; columns } when id = "save_dialog.last_saved" ->
          let move x = x +. (0.001 *. float_of_int (seq mod 3)) in
          (id, Wire.Line_shares { rows = List.map move rows; columns })
      | p -> (id, p))
    probes

let probes ~list ~saved seq = function
  | Menu r -> set (lit "main_menu_row.band" r) menu_frame
  | Save_dialog _ -> jitter seq (if saved then after_save else before_save)
  | Gift_list c -> set (lit "mystery_gift.item" c) list
  | Card -> card_frame
  | Link_play | Gift_menu | Connecting | Stop_receiving _ | Disconnect
  | Disconnected | Saving _ ->
      other_frame

let frame_ms = 50.

(* The console: its screen and clock, every press and screen kept. *)
type console = {
  mutable screen : screen;
  mutable t_ms : float;
  mutable seq : int;
  mutable seen : screen list;
  mutable saved : bool;
}

let frame ~list c : Effects.measurements =
  c.seq <- c.seq + 1;
  c.seen <- c.seen @ [ c.screen ];
  {
    seq = c.seq;
    t_ms = c.t_ms;
    probes = probes ~list ~saved:c.saved c.seq c.screen;
  }

let press c = function
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      List.iter
        (fun b ->
          (match (c.screen, b) with
          | Saving _, Wire.A -> c.saved <- true
          | _ -> ());
          c.screen <- next c.screen b)
        buttons;
      c.t_ms <- c.t_ms +. float_of_int (hold_ms + cooldown_ms)
  | Wait { wait_ms } -> c.t_ms <- c.t_ms +. float_of_int wait_ms

let rec await ~list c check timeout_ms start =
  let m = frame ~list c in
  if check m then Effects.Holds m
  else if c.t_ms -. start > float_of_int timeout_ms then Timeout
  else (
    c.t_ms <- c.t_ms +. frame_ms;
    await ~list c check timeout_ms start)

let on_console ~list c f =
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
              answer (await ~list c check timeout_ms c.t_ms)
          | Effects.Submit commands ->
              List.iter (press c) commands;
              answer { Wire.batch_id = "b"; seq = c.seq; t_ms = c.t_ms }
          | Effects.Read -> answer (Some (frame ~list c))
          | Effects.Now -> answer c.t_ms
          | Effects.Upload_template _ -> answer "name"
          | Effects.Subscribe probes ->
              answer (List.map (fun (p : Wire.probe_spec) -> p.id) probes)
          | Effects.Unsubscribe ids -> answer ids
          | Effects.Save_frame _ -> answer 0
          | _ -> None);
    }

let start screen = { screen; t_ms = 0.; seq = 0; seen = []; saved = false }
let picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let claim ~list =
  let c = start (Menu 3) in
  let log = ref [] in
  let claim =
    on_console ~list c (fun () ->
        Gc.claim
          ~log:(fun l -> log := !log @ [ l ])
          ~picture ~assets:Plza_readers.Blob_assets.file_names
          ~gift_name:(Some "name") gift)
  in
  (claim, c, !log)

let claim_text : Gc.claim -> string = function
  | Received -> "received"
  | Already_received -> "already received"
  | Not_received why -> "not received: " ^ why
  | Lost why -> "lost: " ^ why

let screen_text = function
  | Menu r -> Printf.sprintf "main menu, row %d" r
  | Gift_list c -> Printf.sprintf "gift list, item %d" (c + 1)
  | Stop_receiving _ -> "stop receiving?"
  | Card -> "card"
  | Link_play | Gift_menu | Connecting | Disconnect | Disconnected
  | Save_dialog _ | Saving _ ->
      "other"

(* How often the list's screen came back from "stop receiving?". *)
let cancels seen =
  let rec count n = function
    | Stop_receiving _ :: (Gift_list _ :: _ as rest) -> count (n + 1) rest
    | _ :: rest -> count n rest
    | [] -> n
  in
  count 0 seen

let choose ~list =
  let c = start (Gift_list 0) in
  let log = ref [] in
  let r =
    on_console ~list c (fun () ->
        G.choose_gift ~log:(fun l -> log := !log @ [ l ]))
  in
  match r with
  | Ok () -> String.concat "; " !log ^ " -> " ^ screen_text c.screen
  | Error e -> "error: " ^ e

let save () =
  let c = start (Menu 0) in
  let log = ref [] in
  let r =
    on_console ~list:english_list c (fun () ->
        Sp.save ~log:(fun l -> log := !log @ [ l ]))
  in
  match r with
  | Ok () -> String.concat "; " !log ^ " -> " ^ screen_text c.screen
  | Error e -> "error: " ^ e

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "gift_console"
    [
      case "the list held 1 s over changing frames: the gift chosen"
        (fun () -> choose ~list:english_list)
        "Claiming item 4, the gift. -> card";
      case "the English list: Vivillon received"
        (fun () ->
          let r, c, _ = claim ~list:english_list in
          claim_text r ^ "; " ^ screen_text c.screen)
        "received; main menu, row 5";
      case "the gift not listed: not received, back on the main menu"
        (fun () ->
          let r, c, _ = claim ~list:french_list in
          let why =
            match r with
            | Not_received why -> List.hd (String.split_on_char ':' why)
            | r -> claim_text r
          in
          why ^ "; " ^ screen_text c.screen)
        "the gift is not listed below the cursor; main menu, row 5";
      case "the gift not listed: the list left with B and yes, no B cancelled"
        (fun () ->
          let _, c, _ = claim ~list:french_list in
          string_of_int (cancels c.seen))
        "0";
      case "Last Saved held 1 s over changing shares: saved" save
        "Saved: Last Saved changed. -> main menu, row 0";
    ]
