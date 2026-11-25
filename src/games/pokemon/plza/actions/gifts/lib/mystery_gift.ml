module T = Switch_home.Timed_press
module S = Plza_readers.Mystery_gift_screen
module K = Switch_home.Code_keyboard

let ( let* ) = Result.bind

let probes ~picture ~assets ~gift_name =
  Plza_readers.Main_menu_row.probes ~picture ~assets
  @ S.probes ~picture ~gift_name
  @ K.probes

let a ms : T.t = { button = A; hold_ms = 100; cooldown_ms = ms }
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 300 }
let link_play_row = 5
let a_2s : T.t = { button = A; hold_ms = 100; cooldown_ms = 2000 }

(* "Get with Internet", then connect. *)
let to_internet : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 1500 };
    { button = A; hold_ms = 100; cooldown_ms = 4000 };
  ]

let card_ok : T.t = { button = A; hold_ms = 100; cooldown_ms = 3000 }

(* B, then yes to "stop for now?". *)
let leave_list : T.t list =
  [ { button = B; hold_ms = 100; cooldown_ms = 1500 }; a_2s ]

(* B, yes to "you will be disconnected", A, B. *)
let leave_link : T.t list =
  [
    { button = B; hold_ms = 100; cooldown_ms = 1500 };
    { button = A; hold_ms = 100; cooldown_ms = 4500 };
    { button = A; hold_ms = 100; cooldown_ms = 2500 };
    { button = B; hold_ms = 100; cooldown_ms = 2000 };
  ]

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

(* [check] held for [hold_ms] within [timeout_ms], with no press; the last
   frame read. The held value is compared frame to frame, so it is unit; the
   last frame is kept beside it. *)
let held_read ~timeout_ms ~what ~describe check =
  let last = ref None in
  let watch m =
    last := Some m;
    if check m then Some () else None
  in
  match
    Switch_home.Held_screen.wait_for ~timeout_ms
      (Switch_home.Held_screen.held hold_ms watch)
  with
  | Some () -> Option.to_result ~none:"no frame" !last
  | None ->
      Error (what ^ ": " ^ Option.fold ~none:"no frame" ~some:describe !last)

(* wait_mg_card_and_dismiss's 30 s; the list read for 3 s, the keyboard 5. *)
let card_wait_ms = 30_000
let list_read_ms = 3000
let keyboard_read_ms = 5000

let await_card () =
  Result.map ignore
    (held_read ~timeout_ms:card_wait_ms ~describe:S.describe
       ~what:"no gift card in 30 s (the gift may be received; nothing saved)"
       S.card)

let read_list () =
  held_read ~timeout_ms:list_read_ms ~describe:S.describe
    ~what:"no active gift list" S.list_active

let await_list () = Result.map ignore (read_list ())

let await_keyboard () =
  Result.map ignore
    (held_read ~timeout_ms:keyboard_read_ms ~describe:S.describe
       ~what:"no code keyboard" K.shown)

let dismiss_card ~log =
  let* () = await_card () in
  log "Gift received.";
  T.press card_ok;
  Ok ()

let claim_ms = 8000

let gift_row m =
  match (S.selected_item m, S.gift_item m) with
  | Some at, Some k when k > at -> Ok (at, k)
  | _ ->
      Error
        ("the gift is not listed below the cursor: " ^ S.describe m
       ^ "; nothing claimed")

let on_gift k m = S.list_active m && S.selected_item m = Some k

let choose_gift ~log =
  let* m = read_list () in
  let* at, k = gift_row m in
  T.press_all (T.times (k - at) (dpad Down));
  match Effects.await ~timeout_ms:read_ms (on_gift k) with
  | Timeout ->
      Error
        (Printf.sprintf "the cursor did not reach item %d; nothing claimed"
           (k + 1))
  | Holds _ ->
      log (Printf.sprintf "Claiming item %d, the gift." (k + 1));
      T.press (a claim_ms);
      Ok ()

let leave_card ~log =
  let* () = dismiss_card ~log in
  T.press_all leave_list;
  Ok ()

let plus_ms = 5000

let open_keyboard ~log =
  T.press_all [ dpad Down; a_2s ];
  let* () = until_pressing ~what:"no code keyboard" K.shown in
  log "The code keyboard is open.";
  Ok ()

let claim_code ~log ~picture code =
  let* () = K.type_code ~log ~picture code in
  T.press { button = Start; hold_ms = 100; cooldown_ms = plus_ms };
  let* () = wait_list () in
  log (Printf.sprintf "The gift for %s is listed." (K.normalize code));
  T.press (a claim_ms);
  Ok ()

let disconnect () = T.press_all leave_link
