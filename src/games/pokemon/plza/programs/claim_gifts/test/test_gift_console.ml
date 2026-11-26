(* Gift_claim.claim of the Internet gift (Vivillon), Leave_gifts and
   Save_progress.save on a scripted console: a screen that changes with each
   press as console B's did (2026-11-25), shown as frames 50 ms apart, each
   one the probes of a real capture
   (../../../readers/test/fixtures/gifts/gifts.probes.jsonl, every gift
   probe, the gift's name matched by its English template) with the menu's
   highlighted row or the list's cursor set. The main menu is
   tutorial-cards' it-menu-no-card; the list console B's English one
   (Vivillon item 4) or its French one (no item matches the English name, as
   on the Japanese game's run of 2026-11-25); the card Vivillon's, English or
   Japanese (its title bar over the first item's strip), or an item's with no
   text box; "stop receiving?"
   console B's Japanese list under it, Yes or No highlighted; the Mystery
   Gift menu console B's Japanese one; "disconnect?" its "write a report?"
   question over that menu (no "disconnect?" was captured), its No a copy
   with the other row lit; "disconnected" its "connected" message; Link Play
   connecting and another Link Play option (a battle club, opened when the
   cursor is not on Mystery Gift) the white fade before a card, which no
   reader knows. The
   SAVE dialog is console B's at 18:16 before the save and its copy at 18:18
   after, its "Last Saved" shares changed a little on every frame, as a
   capture's do; its current time is made for the game clock's minute. The
   game saved last in minute 0, and a save within it leaves "Last Saved" as
   it was (console B, 2026-11-26). Nothing reaches a daemon.

   On the console, A on the list claims the item under the cursor, B on the
   list asks "stop receiving?", B there cancels it, and B on the card goes
   back to the list (console B, 2026-11-25). Every way off the list must read
   the screen before A: A only on the claim's own item, never on the list
   otherwise, also when "stop receiving?" is already open as the leave starts
   (the run of 2026-11-25 closed it with B and claimed the first item with
   its A). On the way in, A goes past the list's "choose a gift" prompt
   (console B's Japanese capture of it) only once it has held 1 s: a prompt
   that only flickers over the list, with presses landing 200 ms late, gets
   no A. The list must count once it has shown for 1 s, though no two of
   its frames are equal. The SAVE dialog's "Last Saved" must count once it
   has shown for 1 s, though its shares differ on every frame. *)

module Gc = Plza_claim_gifts.Gift_claim
module G = Plza_claim_gifts.Mystery_gift
module Sp = Plza_claim_gifts.Save_progress
module L = Plza_claim_gifts.Leave_gifts
module Rb = Plza_readers.Received_before

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
let english_card = capture "./mystery-gift/card-vivillon.png"
let japanese_card = capture "./mystery-gift/card-vivillon-ja.png"
let item_card = capture "./mystery-gift/card-item-ja-360p.png"
let other_frame = capture "./mystery-gift/claim-white-fade.png"
let stop_yes = capture "./mystery-gift/gift-list-ja-stop-receiving-yes-360p.png"
let prompt = capture "./mystery-gift/gift-list-ja-choose-prompt-360p.png"
let stop_no = capture "./mystery-gift/gift-list-ja-stop-receiving-no-360p.png"
let gift_menu = capture "./mystery-gift/gift-menu-ja-360p.png"
let question = capture "./mystery-gift/gift-menu-ja-report-question-360p.png"
let message = capture "./mystery-gift/gift-menu-ja-connected-message-360p.png"
let before_save = capture "./mystery-gift/save-dialog-last-saved-1816.png"
let received_before = capture "./mystery-gift/gift-received-before-ja-360p.png"
let code_used = capture "./mystery-gift/code-used-before-ja-360p.png"

let after_save =
  capture "./mystery-gift/synthetic-save-dialog-last-saved-1818.png"

type answer = Yes | No

type screen =
  | Menu of int
  | Link_play
  | Battle_club
  | Gift_menu
  | Connecting
  | Gift_list of int
  | Prompt
  | Fading of float
  | Stop_receiving of int * answer
  | Card
  | Disconnect of answer
  | Disconnected
  | Save_dialog of int
  | Saving of int
  | Code_used

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
  | Battle_club, B -> Link_play
  | Gift_menu, A -> Connecting
  | Gift_menu, B -> Disconnect Yes
  | Connecting, A -> Gift_list 0
  | Gift_list c, Down -> Gift_list (min last_item (c + 1))
  | Gift_list _, A -> Card
  | Gift_list c, B -> Stop_receiving (c, Yes)
  | Prompt, A -> Gift_list 0
  | Prompt, B -> Stop_receiving (0, Yes)
  | Stop_receiving (_, Yes), A -> Gift_menu
  | Stop_receiving (c, No), A -> Gift_list c
  | Stop_receiving (c, _), B -> Gift_list c
  | Stop_receiving (c, _), Up -> Stop_receiving (c, Yes)
  | Stop_receiving (c, _), Down -> Stop_receiving (c, No)
  | Card, B -> Gift_list 0
  | Code_used, (A | B) -> Gift_menu
  | Disconnect Yes, A -> Disconnected
  | Disconnect No, A | Disconnect _, B -> Gift_menu
  | Disconnect _, Up -> Disconnect Yes
  | Disconnect _, Down -> Disconnect No
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

(* "write a report?" with its No highlighted. *)
let no_lit =
  set [ ("mystery_gift.yes", share 0.0); ("mystery_gift.no", share 1.0) ]

let probes ~list ~card ~saved seq = function
  | Menu r -> set (lit "main_menu_row.band" r) menu_frame
  | Save_dialog _ -> jitter seq (if saved then after_save else before_save)
  | Gift_list c -> set (lit "mystery_gift.item" c) list
  | Stop_receiving (c, a) ->
      set (lit "mystery_gift.item" c) (if a = Yes then stop_yes else stop_no)
  | Prompt -> set (lit "mystery_gift.item" 0) prompt
  | Fading _ -> other_frame
  | Card -> card
  | Gift_menu -> gift_menu
  | Disconnect Yes -> question
  | Disconnect No -> no_lit question
  | Disconnected -> message
  | Code_used -> code_used
  | Link_play | Battle_club | Connecting | Saving _ -> other_frame

let frame_ms = 50.

(* The console: its screen and clock, every press and screen kept. *)
type console = {
  mutable screen : screen;
  mutable t_ms : float;
  mutable seq : int;
  mutable seen : screen list;
  mutable saved : bool;
  mutable claimed : int list;
  mutable presses : (screen * Wire.button) list;
  card : (string * Wire.probe_result) list;
  battle : bool;
  after_connect : screen;
  latency_ms : float;
  clock_ms : float option;
      (** How far into the game clock's minute 0 the run starts; [None]: the
          clock stands still in minute 0. *)
}

(* A prompt fading in and out over the list: 400 ms of it, 500 of the list
   alone, again and again, neither ever held 1 s. *)
let fade_period = 900.
let fade_prompt = 400.

let shown c =
  match c.screen with
  | Fading t0 ->
      if Float.rem (c.t_ms -. t0) fade_period < fade_prompt then Prompt
      else Gift_list 0
  | s -> s

(* The game clock's minute: the earlier save was made in minute 0. *)
let minute c =
  match c.clock_ms with
  | None -> 0
  | Some start -> int_of_float ((start +. c.t_ms) /. 60_000.)

(* The dialog's current time, one reading a minute, two apart by 1.0. *)
let now_probe c =
  let x = if minute c mod 2 = 0 then 0.1 else 0.6 in
  ("save_dialog.now", Wire.Line_shares { rows = [ 0.2 ]; columns = [ x; x ] })

let frame ~list c : Effects.measurements =
  c.seq <- c.seq + 1;
  let screen = shown c in
  c.seen <- c.seen @ [ screen ];
  let ps = probes ~list ~card:c.card ~saved:c.saved c.seq screen in
  let ps =
    match screen with Save_dialog _ -> set [ now_probe c ] ps | _ -> ps
  in
  { seq = c.seq; t_ms = c.t_ms; probes = ps }

let press c = function
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      List.iter
        (fun b ->
          c.t_ms <- c.t_ms +. c.latency_ms;
          let screen = shown c in
          c.presses <- c.presses @ [ (screen, b) ];
          (match (screen, b) with
          | Saving _, Wire.A -> c.saved <- minute c <> 0
          | Gift_list k, Wire.A -> c.claimed <- c.claimed @ [ k ]
          | _ -> ());
          c.screen <-
            (match (screen, b) with
            | Link_play, Wire.A when c.battle -> Battle_club
            | Connecting, Wire.A -> (
                match c.after_connect with Fading _ -> Fading c.t_ms | s -> s)
            | s, b -> next s b))
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

let start ?(card = english_card) ?(battle = false)
    ?(after_connect = Gift_list 0) ?(latency_ms = 0.) ?(clock_ms = Some 50_000.)
    screen =
  {
    screen;
    t_ms = 0.;
    seq = 0;
    seen = [];
    saved = false;
    claimed = [];
    presses = [];
    card;
    battle;
    after_connect;
    latency_ms;
    clock_ms;
  }

let picture : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let claim ?card ?battle ?after_connect ?latency_ms ~list () =
  let c = start ?card ?battle ?after_connect ?latency_ms (Menu 3) in
  let log = ref [] in
  let claim =
    on_console ~list c (fun () ->
        Gc.claim
          ~log:(fun l -> log := !log @ [ l ])
          ~picture ~assets:Plza_readers.Blob_assets.file_names
          ~gift_name:(Some "name") ~received_before:Rb.none gift)
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
  | Prompt | Fading _ -> "choose a gift"
  | Link_play | Battle_club | Gift_menu | Connecting | Disconnect _
  | Disconnected | Save_dialog _ | Saving _ | Code_used ->
      "other"

(* How often the list's screen came back from "stop receiving?". *)
let cancels seen =
  let rec count n = function
    | Stop_receiving _ :: (Gift_list _ :: _ as rest) -> count (n + 1) rest
    | _ :: rest -> count n rest
    | [] -> n
  in
  count 0 seen

let items ks = String.concat " " (List.map (fun k -> string_of_int (k + 1)) ks)

(* The items claimed, and the A presses on the list alone. *)
let claims c =
  let on_list =
    List.length
      (List.filter
         (function Gift_list _, Wire.A -> true | _ -> false)
         c.presses)
  in
  Printf.sprintf "claimed [%s], %d A on the list" (items c.claimed) on_list

(* Leave_gifts from [screen]: where it ended, and what it claimed. *)
let leave screen =
  let c = start screen in
  let r =
    on_console ~list:english_list c (fun () -> L.to_main_menu ~log:ignore)
  in
  let ended = match r with Ok () -> screen_text c.screen | Error e -> e in
  ended ^ "; " ^ claims c

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

(* Saved from the main menu, the game clock [clock_ms] into the minute of
   the earlier save. *)
let save ?clock_ms () =
  let c = start ?clock_ms (Menu 0) in
  let log = ref [] in
  let r =
    on_console ~list:english_list c (fun () ->
        Sp.save ~log:(fun l -> log := !log @ [ l ]))
  in
  match r with
  | Ok () -> String.concat "; " !log ^ " -> " ^ screen_text c.screen
  | Error e -> "error: " ^ e

(* Sp.save as above: what came of it, the clock's minute and the A
   presses. *)
let save_a ?clock_ms () () =
  let c = start ?clock_ms (Menu 0) in
  let r = on_console ~list:english_list c (fun () -> Sp.save ~log:ignore) in
  Printf.sprintf "%s; the clock in minute %d; %d A"
    (match r with Ok () -> "saved" | Error e -> "error: " ^ e)
    (minute c)
    (List.length (List.filter (fun (_, b) -> b = Wire.A) c.presses))

(* Mystery_gift.after_code from [screen]: what it read, the A presses and
   where it ended. *)
let after_code screen =
  let c = start screen in
  let r =
    on_console ~list:english_list c (fun () ->
        Effects.with_probes [] (fun () -> G.after_code ~log:ignore "CODE"))
  in
  let a = List.length (List.filter (fun (_, b) -> b = Wire.A) c.presses) in
  (match r with
  | Ok Listed -> "listed"
  | Ok Used_before -> "used before"
  | Error e -> "error: " ^ e)
  ^ Printf.sprintf "; %d A; %s" a (screen_text c.screen)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "gift_console"
    [
      case "the list held 1 s over changing frames: the gift chosen"
        (fun () -> choose ~list:english_list)
        "Claiming item 4, the gift. -> card";
      case "the English list: Vivillon received"
        (fun () ->
          let r, c, _ = claim ~list:english_list () in
          claim_text r ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "received; main menu, row 5; claimed [4], 1 A on the list";
      case "the Japanese card: Vivillon received"
        (fun () ->
          let r, c, _ = claim ~card:japanese_card ~list:english_list () in
          claim_text r ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "received; main menu, row 5; claimed [4], 1 A on the list";
      case "an Internet gift received before: already received"
        (fun () ->
          let r, c, _ = claim ~card:received_before ~list:english_list () in
          claim_text r ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "already received; main menu, row 5; claimed [4], 1 A on the list";
      case "a code used before: no A on its message"
        (fun () -> after_code Code_used)
        "used before; 0 A; other";
      case "a code's gift listed: A claims it"
        (fun () -> after_code (Gift_list 0))
        "listed; 1 A; card";
      case "an item's card, no text box: received"
        (fun () ->
          let r, c, _ = claim ~card:item_card ~list:english_list () in
          claim_text r ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "received; main menu, row 5; claimed [4], 1 A on the list";
      case
        "Link Play's A opens another option: not received, nothing pressed \
         there but B"
        (fun () ->
          let r, c, _ = claim ~battle:true ~list:english_list () in
          let why =
            match r with
            | Not_received why -> List.hd (String.split_on_char ':' why)
            | r -> claim_text r
          in
          let pressed =
            List.sort_uniq compare
              (List.filter_map
                 (function
                   | Battle_club, b -> Some (Wire.string_of_button b)
                   | _ -> None)
                 c.presses)
          in
          Printf.sprintf "%s; %s; on it: %s" why (screen_text c.screen)
            (String.concat " " pressed))
        "Link Play's A did not open the Mystery Gift menu; main menu, row 5; \
         on it: B";
      case
        "the list's \"choose a gift\" prompt held: A past it, Vivillon received"
        (fun () ->
          let r, c, _ = claim ~after_connect:Prompt ~list:english_list () in
          claim_text r ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "received; main menu, row 5; claimed [4], 1 A on the list";
      case
        "a prompt fading in and out over the list, presses 200 ms late: no A \
         on the list"
        (fun () ->
          let r, c, _ =
            claim ~after_connect:(Fading 0.) ~latency_ms:200. ~list:english_list
              ()
          in
          let why =
            match r with
            | Not_received why -> List.hd (String.split_on_char ':' why)
            | r -> claim_text r
          in
          why ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "no active gift list after 25 reads; main menu, row 5; claimed [], 0 A \
         on the list";
      case "the gift not listed: not received, back on the main menu"
        (fun () ->
          let r, c, _ = claim ~list:french_list () in
          let why =
            match r with
            | Not_received why -> List.hd (String.split_on_char ':' why)
            | r -> claim_text r
          in
          why ^ "; " ^ screen_text c.screen ^ "; " ^ claims c)
        "the gift is not listed below the cursor; main menu, row 5; claimed \
         [], 0 A on the list";
      case "the gift not listed: the list left with B and yes, no B cancelled"
        (fun () ->
          let _, c, _ = claim ~list:french_list () in
          string_of_int (cancels c.seen))
        "0";
      case "leaving with \"stop receiving?\" already open: yes, nothing claimed"
        (fun () -> leave (Stop_receiving (0, Yes)))
        "main menu, row 5; claimed [], 0 A on the list";
      case "leaving with \"stop receiving?\" on No: Up, yes, nothing claimed"
        (fun () -> leave (Stop_receiving (0, No)))
        "main menu, row 5; claimed [], 0 A on the list";
      case "leaving from the card: B, nothing claimed"
        (fun () -> leave Card)
        "main menu, row 5; claimed [], 0 A on the list";
      case "leaving from the list: nothing claimed"
        (fun () -> leave (Gift_list 2))
        "main menu, row 5; claimed [], 0 A on the list";
      case "leaving from \"disconnect?\" on No: nothing claimed"
        (fun () -> leave (Disconnect No))
        "main menu, row 5; claimed [], 0 A on the list";
      case "Last Saved held 1 s over changing shares: saved" save
        "The current time changed: saving.; Saved: Last Saved changed. -> main \
         menu, row 0";
      case "the dialog opened 10 s before the minute changes: waits, then saved"
        (save_a ()) "saved; the clock in minute 1; 2 A";
      case "the clock stands still: no A, not saved" (save_a ~clock_ms:None ())
        "error: the current time did not change within 65 s: not saved; the \
         clock in minute 0; 0 A";
    ]
