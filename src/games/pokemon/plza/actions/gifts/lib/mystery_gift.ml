module T = Switch_home.Timed_press
module S = Plza_readers.Mystery_gift_screen
module K = Switch_home.Code_keyboard

let ( let* ) = Result.bind

let probes ~picture ~assets =
  Plza_readers.Main_menu_row.probes ~picture ~assets
  @ S.probes ~picture @ K.probes

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

(* wait_mg_card_and_dismiss: 15 reads, 2 s apart. *)
let card_wait_ms = 2000
let card_reads = 15

let dismiss_card ~log =
  let rec go n =
    if n >= card_reads then
      Error "no gift card in 30 s: the gift may be received; nothing saved"
    else (
      Switch_home.Switch_presses.wait card_wait_ms;
      match Effects.read () with
      | Some m when S.card m ->
          log "Gift received.";
          T.press card_ok;
          Ok ()
      | Some _ | None -> go (n + 1))
  in
  go 0

let fourth_gift = 3
let claim_ms = 8000

let claim_internet ~log =
  T.press_all (T.times fourth_gift (dpad Down) @ [ a claim_ms ]);
  let* () = dismiss_card ~log in
  T.press_all leave_list;
  Ok ()

let plus_ms = 5000

let claim_code ~log ~picture code =
  T.press_all [ dpad Down; a_2s ];
  let* () = until_pressing ~what:"no code keyboard" K.shown in
  let* () = K.type_code ~log ~picture code in
  T.press { button = Start; hold_ms = 100; cooldown_ms = plus_ms };
  let* () = wait_list () in
  log (Printf.sprintf "The gift for %s is listed." (K.normalize code));
  T.press (a claim_ms);
  dismiss_card ~log

let disconnect () = T.press_all leave_link
