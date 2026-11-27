module T = Switch.Timed_press
module S = Plza_readers.Mystery_gift_screen
module K = Switch.Code_keyboard

let ( let* ) = Result.bind

let probes ~picture ~assets ~gift_name =
  Plza_readers.Main_menu_row.probes ~picture ~assets
  @ Plza_readers.Info_card.probes ~picture
  @ S.probes ~picture ~gift_name
  @ K.probes
  @ Plza_readers.Boxes_screen.probes ~picture
  @ Plza_readers.Box_cell.probes ~picture
  @ Plza_readers.Box_title.probes ~picture
  @ Plza_readers.Tutorial_card.probes ~picture
  @ Plza_readers.Save_dialog.probes ~picture

let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 300 }
let link_play_row = 5
let a_2s : T.t = { button = A; hold_ms = 100; cooldown_ms = 2000 }

(* "Get with Internet", then connect. *)
let to_internet : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
    { button = A; hold_ms = 100; cooldown_ms = 4000 };
  ]

let claim_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 8000 }

(* [check] held for [hold_ms] within [read_ms]; else A, up to [rounds]
   times, but only once a screen where A answers what it shows has held
   [hold_ms] too: never on the gift list without its text box (A would claim
   the selected gift), nor on a frame or two of its "choose a gift" prompt
   fading out, nor on no frame. *)
let hold_ms = 1000.
let read_ms = 1500
let rounds = 25

let held check =
  Screen_graph.Held_screen.held hold_ms (fun m ->
      if check m then Some () else None)

let a_answers m = S.text_up m || not (S.list_shown m)

type read = Ready | Answer

(* The first of [check] and [a_answers] to hold; [check] first on a frame
   where both do. *)
let watch check =
  let ready = held check and answer = held a_answers in
  fun m ->
    let r = ready m and a = answer m in
    if Option.is_some r then Some Ready else Option.map (fun () -> Answer) a

let until_pressing ~what check =
  let rec go n =
    match
      Screen_graph.Held_screen.wait_for ~timeout_ms:read_ms (watch check)
    with
    | Some Ready -> Ok ()
    | (Some Answer | None) when n >= rounds ->
        Error (Printf.sprintf "%s after %d reads" what rounds)
    | Some Answer ->
        T.press a_2s;
        go (n + 1)
    | None -> go (n + 1)
  in
  go 0

(* The Mystery Gift menu held 1 s within 3 s after Link Play's A: another
   Link Play option is left by the way back, not pressed on. *)
let menu_read_ms = 3000

let open_gifts ~log =
  let* () = Menu_rows.goto ~log link_play_row in
  T.press_all ([ a_2s ] @ T.times 2 (dpad Right) @ [ dpad Down; a_2s ]);
  let last = ref None in
  let watch m =
    last := Some m;
    S.gift_menu m
  in
  match
    Screen_graph.Held_screen.wait_for ~timeout_ms:menu_read_ms (held watch)
  with
  | Some () ->
      log "Mystery Gift.";
      Ok ()
  | None ->
      Error
        ("Link Play's A did not open the Mystery Gift menu: "
        ^ Option.fold ~none:"no frame" ~some:S.describe !last)

let wait_list () = until_pressing ~what:"no active gift list" S.list_active

let open_internet_list ~log =
  T.press_all to_internet;
  let* () = wait_list () in
  log "The Internet gift list is active.";
  Ok ()

(* The list read for 1 s within 3 s, with no press (A would claim the
   selected gift); the last frame read. The hold is on the list showing, not
   on the frame: no two frames are equal. *)
let list_read_ms = 3000

let read_list () =
  let last = ref None in
  let shown m =
    last := Some m;
    S.list_active m
  in
  let read =
    Screen_graph.Held_screen.wait_for ~timeout_ms:list_read_ms (held shown)
  in
  match (read, !last) with
  | Some (), Some m -> Ok m
  | _ ->
      Error
        ("no active gift list: "
        ^ Option.fold ~none:"no frame" ~some:S.describe !last)

let gift_row m =
  match (S.selected_item m, S.gift_item m) with
  | Some at, Some k when k > at -> Ok (at, k)
  | _ -> Error ("the gift is not listed below the cursor: " ^ S.describe m)

let on_gift k m = S.list_active m && S.selected_item m = Some k

let choose_gift ~log =
  let* m = read_list () in
  let* at, k = gift_row m in
  T.press_all (T.times (k - at) (dpad Down));
  match Effects.await ~timeout_ms:read_ms (on_gift k) with
  | Timeout -> Error (Printf.sprintf "the cursor did not reach item %d" (k + 1))
  | Holds _ ->
      log (Printf.sprintf "Claiming item %d, the gift." (k + 1));
      T.press claim_a;
      Ok ()

let plus_ms = 5000

let open_keyboard ~log =
  T.press_all [ dpad Down; a_2s ];
  let* () = until_pressing ~what:"no code keyboard" K.shown in
  log "The code keyboard is open.";
  Ok ()

type entered = Listed | Used_before

let after_code ~log code =
  let used = ref false in
  let check m =
    used := Plza_readers.Info_card.shown m;
    !used || S.list_active m
  in
  let* () = until_pressing ~what:"no active gift list" check in
  if !used then (
    log (Printf.sprintf "The code %s was used before." (K.normalize code));
    Ok Used_before)
  else (
    log (Printf.sprintf "The gift for %s is listed." (K.normalize code));
    T.press claim_a;
    Ok Listed)

let enter_code ~log ~picture code =
  let* () = K.type_code ~log ~picture code in
  T.press { button = Start; hold_ms = 100; cooldown_ms = plus_ms };
  after_code ~log code

let card_shown = S.card
let describe = S.describe
