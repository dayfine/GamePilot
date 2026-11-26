module R = Plza_readers.Main_menu_row
module C = Plza_gift_catalog.Gift_catalog

let name_template ~id ~language =
  Printf.sprintf "src/games/pokemon/plza/assets/gift-name-%s-%s.png" id language

let parties = 6
let read_ms = 1500

(* Five or six cards green, the rest empty: the party, as Claim_gifts takes
   it. *)
let party_of m =
  let green = List.filter (R.card_green m) (List.init parties Fun.id) in
  let empty = List.filter (R.card_empty m) (List.init parties Fun.id) in
  match (List.length green, empty) with
  | n, [] when n = parties -> Some Claim_gifts.Full
  | n, [ last ] when n = parties - 1 && last = parties - 1 ->
      Some Claim_gifts.Room_for_one
  | _ -> None

let shares m =
  String.concat " " (List.map (Printf.sprintf "%.2f") (R.green_shares m))

let party_read m : Claim_gifts.party_read =
  match party_of m with Some p -> Party p | None -> Not_ready (shares m)

let unread () : Claim_gifts.party_read =
  Not_ready
    ("HP bars green: "
    ^ Option.fold ~none:"no frame" ~some:shares (Effects.read ()))

let read_party ~log () : Claim_gifts.party_read =
  match Menu_rows.open_menu ~log with
  | Error why -> No_menu why
  | Ok _ -> (
      match Effects.await ~timeout_ms:read_ms (fun m -> party_of m <> None) with
      | Holds m -> party_read m
      | Timeout -> unread ())

let gift_name ~name_templates (gift : C.gift) =
  Option.map Effects.upload_template (List.assoc_opt gift.id name_templates)

let game_steps ~log ~picture ~assets ~name_templates : Claim_gifts.game_steps =
  let probed f =
    Effects.with_probes (Mystery_gift.probes ~picture ~assets ~gift_name:None) f
  in
  {
    read_party = (fun () -> probed (read_party ~log));
    claim =
      (fun gift ->
        Gift_claim.claim ~log ~picture ~assets
          ~gift_name:(gift_name ~name_templates gift)
          gift);
    check_slots =
      (fun ~party_gift ~in_box ->
        probed (fun () -> Gift_boxes.check ~log ~party_gift ~in_box));
    save = (fun () -> probed (fun () -> Save_progress.save ~log));
    log;
  }

let actions ~catalog ~today ~name_templates ~log ~picture ~assets =
  Claim_gifts.game_actions
    (game_steps ~log ~picture ~assets ~name_templates)
    (Claim_gifts.start catalog ~today)
