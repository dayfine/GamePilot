module T = Switch_home.Timed_press
module S = Plza_readers.Mystery_gift_screen
module K = Switch_home.Code_keyboard

let ( let* ) = Result.bind

let probes ~picture ~assets ~gift_name =
  Plza_readers.Main_menu_row.probes ~picture ~assets
  @ S.probes ~picture ~gift_name
  @ K.probes
  @ Plza_readers.Boxes_screen.probes ~picture
  @ Plza_readers.Box_cell.probes ~picture
  @ Plza_readers.Save_dialog.probes ~picture

let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 300 }
let link_play_row = 5
let a_2s : T.t = { button = A; hold_ms = 100; cooldown_ms = 2000 }
let b_1500 : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }

(* "Get with Internet", then connect. *)
let to_internet : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
    { button = A; hold_ms = 100; cooldown_ms = 4000 };
  ]

(* B, then yes to "stop for now?". *)
let stop_list = [ b_1500; a_2s ]

(* B, yes to "you will be disconnected", A, B. *)
let leave_link : T.t list =
  [
    b_1500;
    { button = A; hold_ms = 100; cooldown_ms = 4500 };
    { button = A; hold_ms = 100; cooldown_ms = 2500 };
    { button = B; hold_ms = 100; cooldown_ms = 2000 };
  ]

let claim_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 8000 }
let card_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 3000 }

let open_gifts ~log =
  let* () = Menu_rows.goto ~log link_play_row in
  T.press_all ([ a_2s ] @ T.times 2 (dpad Right) @ [ dpad Down; a_2s ]);
  log "Mystery Gift.";
  Ok ()

(* [check] held for [hold_ms] within [read_ms]; else A, up to [rounds]
   times. *)
let hold_ms = 1000.
let read_ms = 1500
let rounds = 25

let held check =
  Switch_home.Held_screen.held hold_ms (fun m ->
      if check m then Some () else None)

let until_pressing ~what check =
  let rec go n =
    match Switch_home.Held_screen.wait_for ~timeout_ms:read_ms (held check) with
    | Some () -> Ok ()
    | None when n >= rounds ->
        Error (Printf.sprintf "%s after %d A presses" what rounds)
    | None ->
        T.press a_2s;
        go (n + 1)
  in
  go 0

let wait_list () = until_pressing ~what:"no active gift list" S.list_active

let open_internet_list ~log =
  T.press_all to_internet;
  let* () = wait_list () in
  log "The Internet gift list is active.";
  Ok ()

(* The list read for 1 s within 3 s, with no press (A would claim the
   selected gift); the last frame read. *)
let list_read_ms = 3000

let read_list () =
  let last = ref None in
  let watch m =
    last := Some m;
    if S.list_active m then Some m else None
  in
  match
    Switch_home.Held_screen.wait_for ~timeout_ms:list_read_ms
      (Switch_home.Held_screen.held hold_ms watch)
  with
  | Some m -> Ok m
  | None ->
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

let leave_list () = T.press_all stop_list
let plus_ms = 5000

let open_keyboard ~log =
  T.press_all [ dpad Down; a_2s ];
  let* () = until_pressing ~what:"no code keyboard" K.shown in
  log "The code keyboard is open.";
  Ok ()

let enter_code ~log ~picture code =
  let* () = K.type_code ~log ~picture code in
  T.press { button = Start; hold_ms = 100; cooldown_ms = plus_ms };
  let* () = wait_list () in
  log (Printf.sprintf "The gift for %s is listed." (K.normalize code));
  T.press claim_a;
  Ok ()

let card_shown = S.card
let describe = S.describe
let dismiss_card () = T.press card_a
let disconnect () = T.press_all leave_link
