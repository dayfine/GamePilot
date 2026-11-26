module G = Mystery_gift
module C = Plza_gift_catalog.Gift_catalog

let ( let* ) = Result.bind

type claim =
  | Received
  | Already_received
  | Not_received of string
  | Lost of string

let already_received = Plza_readers.Info_card.shown

type reached = Pressed | Used_before

(* The presses up to the claim, from the main menu. *)
let reach ~log ~picture ~gift_name (gift : C.gift) =
  match (gift.how, gift.code, gift_name) with
  | Internet, _, Some _ ->
      let* () = G.open_gifts ~log in
      let* () = G.open_internet_list ~log in
      let* () = G.choose_gift ~log in
      Ok Pressed
  | Internet, _, None -> Error "no template of its name in the game's language"
  | Code, Some code, _ ->
      let* () = G.open_gifts ~log in
      let* () = G.open_keyboard ~log in
      let* entered = G.enter_code ~log ~picture code in
      Ok (match entered with Listed -> Pressed | Used_before -> Used_before)
  | Code, None, _ -> Error "a code gift with no code"
  | Home, _, _ -> Error "HOME gifts are received in Pokémon HOME"

type after = Card | Already

(* The message first: its white box reads white over the card's header. *)
let after_claim m =
  if already_received m then Some Already
  else if G.card_shown m then Some Card
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

let ended ~log outcome =
  match Leave_gifts.to_main_menu ~log with
  | Ok () -> outcome
  | Error e -> Lost e

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

let after_claim_read ~log (gift : C.gift) =
  match read_after () with
  | Some Card, _ ->
      log (Printf.sprintf "Gift %s received." gift.id);
      ended ~log Received
  | Some Already, _ ->
      log (Printf.sprintf "Gift %s: already received." gift.id);
      ended ~log Already_received
  | None, last -> ended ~log (unknown ~log gift last)

let claim_probed ~log ~picture ~gift_name (gift : C.gift) =
  match reach ~log ~picture ~gift_name gift with
  | Ok Pressed -> after_claim_read ~log gift
  | Ok Used_before ->
      log (Printf.sprintf "Gift %s: already received (its code used)." gift.id);
      ended ~log Already_received
  | Error e ->
      log (Printf.sprintf "Gift %s not claimed: %s." gift.id e);
      ended ~log (Not_received e)

let claim ~log ~picture ~assets ~gift_name gift =
  Effects.with_probes (G.probes ~picture ~assets ~gift_name) (fun () ->
      claim_probed ~log ~picture ~gift_name gift)
