module G = Mystery_gift
module C = Plza_gift_catalog.Gift_catalog
module T = Switch_home.Timed_press

let ( let* ) = Result.bind

type claim =
  | Received
  | Already_received
  | Not_received of string
  | Lost of string

let already_received (_ : Effects.measurements) = false

(* The presses up to the claim, from the main menu. *)
let reach ~log ~picture ~gift_name (gift : C.gift) =
  match (gift.how, gift.code, gift_name) with
  | Internet, _, Some _ ->
      let* () = G.open_gifts ~log in
      let* () = G.open_internet_list ~log in
      G.choose_gift ~log
  | Internet, _, None -> Error "no template of its name in the game's language"
  | Code, Some code, _ ->
      let* () = G.open_gifts ~log in
      let* () = G.open_keyboard ~log in
      G.enter_code ~log ~picture code
  | Code, None, _ -> Error "a code gift with no code"
  | Home, _, _ -> Error "HOME gifts are received in Pokémon HOME"

type after = Card | Already

let after_claim m =
  if G.card_shown m then Some Card
  else if already_received m then Some Already
  else None

let card_wait_ms = 30_000
let hold_ms = 1000.

(* The screen after the claim, held 1 s within 30 s; the last frame read. *)
let read_after () =
  let last = ref None in
  let watch m =
    last := Some m;
    after_claim m
  in
  let read =
    Switch_home.Held_screen.wait_for ~timeout_ms:card_wait_ms
      (Switch_home.Held_screen.held hold_ms watch)
  in
  (read, !last)

let back_b : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let most_b = 8
let disconnect_after = 4

let rec back_to_menu ~log n =
  match Menu_rows.read_row () with
  | Some _ -> Ok ()
  | None when n >= most_b -> Error "no main menu after 8 B"
  | None ->
      if n = disconnect_after then G.disconnect () else T.press back_b;
      back_to_menu ~log (n + 1)

let ended ~log outcome =
  match back_to_menu ~log 0 with Ok () -> outcome | Error e -> Lost e

let frame_name (gift : C.gift) = "gift-" ^ gift.id ^ "-unknown-screen.png"

let unknown ~log gift last =
  Effects.save_run_frame (frame_name gift);
  let read = Option.fold ~none:"no frame" ~some:G.describe last in
  log
    (Printf.sprintf "Gift %s: unknown screen, kept as %s (%s)." gift.id
       (frame_name gift) read);
  Not_received
    (Printf.sprintf "unknown screen after the claim, kept as %s"
       (frame_name gift))

(* Off the list (an Internet gift's) and off the link, on the main menu. *)
let leave (gift : C.gift) =
  if gift.how = Internet then G.leave_list ();
  G.disconnect ()

let after_claim_read ~log (gift : C.gift) =
  match read_after () with
  | Some Card, _ ->
      log (Printf.sprintf "Gift %s received." gift.id);
      G.dismiss_card ();
      leave gift;
      ended ~log Received
  | Some Already, _ ->
      log (Printf.sprintf "Gift %s: already received." gift.id);
      G.dismiss_card ();
      ended ~log Already_received
  | None, last -> ended ~log (unknown ~log gift last)

let claim_probed ~log ~picture ~gift_name (gift : C.gift) =
  match reach ~log ~picture ~gift_name gift with
  | Ok () -> after_claim_read ~log gift
  | Error e ->
      log (Printf.sprintf "Gift %s not claimed: %s." gift.id e);
      ended ~log (Not_received e)

let claim ~log ~picture ~assets ~gift_name gift =
  Effects.with_probes (G.probes ~picture ~assets ~gift_name) (fun () ->
      claim_probed ~log ~picture ~gift_name gift)
