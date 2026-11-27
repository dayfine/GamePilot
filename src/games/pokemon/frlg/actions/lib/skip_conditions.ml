let pokedex_seen = "pokedex_seen"
let pokedex_not_seen = "pokedex_not_seen"
let party_slot_holds_mail = "party_slot_holds_mail"
let party_has_species = "party_has_species"
let bag_has_item = "bag_has_item"
let coins_at_least = "coins_at_least"
let max_party_slot = 6

type pokedex = { species : string; seen : bool }

type parsed =
  | Pokedex of pokedex
  | Party_mail of int
  | Party_species of string
  | Bag_item of { slug : string; min_qty : int }
  | Coins of int

let split_prefix condition =
  match String.index_opt condition ':' with
  | None -> None
  | Some i ->
      let kind = String.sub condition 0 i in
      let arg =
        String.sub condition (i + 1) (String.length condition - i - 1)
      in
      Some (kind, arg)

(* The species a Pokédex condition names, and whether it holds when the
   species is seen. *)
let pokedex_condition condition =
  match split_prefix condition with
  | Some (k, species) when k = pokedex_seen -> Some { species; seen = true }
  | Some (k, species) when k = pokedex_not_seen ->
      Some { species; seen = false }
  | _ -> None

let parse_slot arg =
  match int_of_string_opt arg with
  | Some n when 1 <= n && n <= max_party_slot -> Some n
  | _ -> None

let parse_positive arg =
  match int_of_string_opt arg with Some n when n >= 1 -> Some n | _ -> None

let parse_bag_arg arg =
  match String.split_on_char ':' arg with
  | [ slug; qty ] when slug <> "" ->
      Option.map (fun min_qty -> (slug, min_qty)) (parse_positive qty)
  | _ -> None

let parse_condition condition =
  match split_prefix condition with
  | Some (k, species) when k = pokedex_seen ->
      Some (Pokedex { species; seen = true })
  | Some (k, species) when k = pokedex_not_seen ->
      Some (Pokedex { species; seen = false })
  | Some (k, arg) when k = party_slot_holds_mail ->
      Option.map (fun s -> Party_mail s) (parse_slot arg)
  | Some (k, slug) when k = party_has_species && slug <> "" ->
      Some (Party_species slug)
  | Some (k, arg) when k = bag_has_item ->
      Option.map
        (fun (slug, min_qty) -> Bag_item { slug; min_qty })
        (parse_bag_arg arg)
  | Some (k, arg) when k = coins_at_least ->
      Option.map (fun n -> Coins n) (parse_positive arg)
  | _ -> None

let reads_pokedex condition = pokedex_condition condition <> None

let reads_species condition =
  match split_prefix condition with
  | Some (k, _) ->
      k = pokedex_seen || k = pokedex_not_seen || k = party_has_species
  | None -> false

let unknown_pokedex condition slug =
  Error
    (Printf.sprintf "skip_if %s: %s is no Kanto Pokedex species" condition slug)

let unknown_species condition slug =
  Error (Printf.sprintf "skip_if %s: %s is no FireRed species" condition slug)

let check_mail_syntax condition arg =
  match parse_slot arg with
  | Some _ -> Ok ()
  | None ->
      Error
        (Printf.sprintf "skip_if %s: %s is not a party slot (1..%d)" condition
           arg max_party_slot)

let check_bag_syntax condition arg =
  match parse_bag_arg arg with
  | Some _ -> Ok ()
  | None ->
      Error
        (Printf.sprintf "skip_if %s: expected <item-slug>:<min_qty>=1" condition)

let check_coins_syntax condition arg =
  match parse_positive arg with
  | Some _ -> Ok ()
  | None ->
      Error
        (Printf.sprintf "skip_if %s: %s is not a positive coin count" condition
           arg)

let check_syntax condition =
  match split_prefix condition with
  | Some (k, arg) when k = party_slot_holds_mail ->
      check_mail_syntax condition arg
  | Some (k, "") when k = party_has_species ->
      Error (Printf.sprintf "skip_if %s: species slug is empty" condition)
  | Some (k, arg) when k = bag_has_item -> check_bag_syntax condition arg
  | Some (k, arg) when k = coins_at_least -> check_coins_syntax condition arg
  | _ -> Ok ()

let check_species species condition =
  match split_prefix condition with
  | Some (k, slug) when k = pokedex_seen || k = pokedex_not_seen ->
      if Pokedex_entry.number_of species slug = None then
        unknown_pokedex condition slug
      else Ok ()
  | Some (k, slug) when k = party_has_species ->
      if List.assoc_opt slug species = None then unknown_species condition slug
      else Ok ()
  | _ -> Ok ()

let check species condition =
  Result.bind (check_syntax condition) (fun () ->
      check_species species condition)

let not_read cause =
  ( "not read ("
    ^ Pokemon_engine.Failure.cause_to_string cause
    ^ "), so not skipped",
    false )

let unread = ("not read, so not skipped", false)

let answer ~seen = function
  | Ok (Pokedex_entry.(Seen | Caught) as e) -> (Pokedex_entry.entry_name e, seen)
  | Ok Not_seen -> ("not seen", not seen)
  | Error cause -> not_read cause

let mail_answer ~slot = function
  | Error cause -> not_read cause
  | Ok marks -> (
      match List.nth_opt marks (slot - 1) with
      | Some Frlg_readers.Party_menu.Mail -> ("mail", true)
      | Some mark -> (Frlg_readers.Party_menu.mark_name mark, false)
      | None -> ("empty", false))

let species_answer ~species = function
  | Error cause -> not_read cause
  | Ok members ->
      if List.mem (Some species) members then ("in party", true)
      else ("not in party", false)

let bag_answer ~min_qty = function
  | Error cause -> not_read cause
  | Ok None -> unread
  | Ok (Some n) -> (Printf.sprintf "%d (need %d)" n min_qty, n >= min_qty)

let coins_answer ~min = function
  | Error cause -> not_read cause
  | Ok None -> unread
  | Ok (Some n) -> (Printf.sprintf "%d coins (need %d)" n min, n >= min)

let back_to_overworld ~log =
  ignore
    (Menu_input.run (fun () ->
         Menu_input.settle_back ~label:"skip read failed" ~log))

let run_read ~log body =
  let value = ref None in
  match Menu_input.run (fun () -> value := Some (body ())) with
  | Ok () -> Ok (Option.get !value)
  | Error cause ->
      back_to_overworld ~log;
      Error cause

let read_party_marks ~log () =
  run_read ~log (fun () -> Mail_glitch_use.read_marks ~log)

let read_party_species ~log () =
  run_read ~log (fun () -> Party_species.read_all ~log)

let read_bag_count ~log slug =
  if Berry_pouch.is_berry slug then
    match run_read ~log (fun () -> Berry_pouch.count ~log slug) with
    | Error { code = "not_in_bag"; _ } -> Ok (Some 0)
    | other -> other
  else run_read ~log (fun () -> Bag_items.count ~log slug)

let read_coins ~log () =
  match run_read ~log (fun () -> Coin_case.read ~log) with
  | Error { code = "not_in_bag"; _ } -> Ok (Some 0)
  | other -> other

type readers = {
  entry : string -> (Pokedex_entry.entry, Pokemon_engine.Failure.cause) result;
  marks :
    unit ->
    (Frlg_readers.Party_menu.mark list, Pokemon_engine.Failure.cause) result;
  party : unit -> (string option list, Pokemon_engine.Failure.cause) result;
  bag : string -> (int option, Pokemon_engine.Failure.cause) result;
  coins : unit -> (int option, Pokemon_engine.Failure.cause) result;
}

let evaluate readers = function
  | Pokedex p -> answer ~seen:p.seen (readers.entry p.species)
  | Party_mail slot -> mail_answer ~slot (readers.marks ())
  | Party_species species -> species_answer ~species (readers.party ())
  | Bag_item { slug; min_qty } -> bag_answer ~min_qty (readers.bag slug)
  | Coins min -> coins_answer ~min (readers.coins ())

let condition_holds ~log readers condition =
  match parse_condition condition with
  | None -> false
  | Some parsed ->
      let what, holds = evaluate readers parsed in
      log (Printf.sprintf "[Skip] %s: %s." condition what);
      holds

let holds ~log =
  condition_holds ~log
    {
      entry = Pokedex_entry_steps.read ~log;
      marks = read_party_marks ~log;
      party = read_party_species ~log;
      bag = read_bag_count ~log;
      coins = read_coins ~log;
    }

let remembered read =
  let answers = Hashtbl.create 4 in
  fun condition ->
    match Hashtbl.find_opt answers condition with
    | Some holds -> holds
    | None ->
        let holds = read condition in
        Hashtbl.replace answers condition holds;
        holds

let read_once ~log =
  let marks = remembered (fun _ -> read_party_marks ~log ()) in
  let party = remembered (fun _ -> read_party_species ~log ()) in
  let coins = remembered (fun _ -> read_coins ~log ()) in
  condition_holds ~log
    {
      entry = remembered (Pokedex_entry_steps.read ~log);
      marks = (fun () -> marks "party_marks");
      party = (fun () -> party "party_species");
      bag = remembered (read_bag_count ~log);
      coins = (fun () -> coins "coins");
    }
