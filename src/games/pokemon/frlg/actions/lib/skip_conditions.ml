let pokedex_seen = "pokedex_seen"
let pokedex_not_seen = "pokedex_not_seen"
let party_slot_holds_mail = "party_slot_holds_mail"
let max_party_slot = 6

type pokedex = { species : string; seen : bool }

let after prefix condition =
  let prefix = prefix ^ ":" in
  if String.starts_with ~prefix condition then
    let n = String.length prefix in
    Some (String.sub condition n (String.length condition - n))
  else None

(* The species a Pokédex condition names, and whether it holds when the
   species is seen. *)
let pokedex_condition condition =
  match (after pokedex_seen condition, after pokedex_not_seen condition) with
  | Some species, _ -> Some { species; seen = true }
  | None, Some species -> Some { species; seen = false }
  | None, None -> None

let mail_slot_arg condition = after party_slot_holds_mail condition

let parse_slot arg =
  match int_of_string_opt arg with
  | Some n when 1 <= n && n <= max_party_slot -> Some n
  | _ -> None

let reads_pokedex condition = pokedex_condition condition <> None

let unknown condition slug =
  Error
    (Printf.sprintf "skip_if %s: %s is no Kanto Pokedex species" condition slug)

let check_syntax condition =
  match mail_slot_arg condition with
  | None -> Ok ()
  | Some arg when parse_slot arg <> None -> Ok ()
  | Some arg ->
      Error
        (Printf.sprintf "skip_if %s: %s is not a party slot (1..%d)" condition
           arg max_party_slot)

let check species condition =
  Result.bind (check_syntax condition) (fun () ->
      match pokedex_condition condition with
      | None -> Ok ()
      | Some p when Pokedex_entry.number_of species p.species = None ->
          unknown condition p.species
      | Some _ -> Ok ())

let not_read cause =
  ( "not read ("
    ^ Pokemon_engine.Failure.cause_to_string cause
    ^ "), so not skipped",
    false )

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

let read_party_marks ~log () =
  let marks = ref [] in
  Result.map
    (fun () -> !marks)
    (Menu_input.run (fun () -> marks := Mail_glitch_use.read_marks ~log))

(* [entry] reads the species' Pokédex entry; [marks] reads the party's marks. *)
let condition_holds ~log ~entry ~marks condition =
  match (pokedex_condition condition, mail_slot_arg condition) with
  | Some p, _ ->
      let what, holds = answer ~seen:p.seen (entry p.species) in
      log (Printf.sprintf "[Skip] %s: %s." condition what);
      holds
  | None, Some arg -> (
      match parse_slot arg with
      | Some slot ->
          let what, holds = mail_answer ~slot (marks ()) in
          log (Printf.sprintf "[Skip] %s: %s." condition what);
          holds
      | None -> false)
  | None, None -> false

let holds ~log =
  condition_holds ~log
    ~entry:(Pokedex_entry_steps.read ~log)
    ~marks:(read_party_marks ~log)

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
  condition_holds ~log
    ~entry:(remembered (Pokedex_entry_steps.read ~log))
    ~marks:(fun () -> marks "party_marks")
