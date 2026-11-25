let pokedex_seen = "pokedex_seen"
let pokedex_not_seen = "pokedex_not_seen"

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

let reads_pokedex condition = pokedex_condition condition <> None

let unknown condition slug =
  Error
    (Printf.sprintf "skip_if %s: %s is no Kanto Pokedex species" condition slug)

let check species condition =
  match pokedex_condition condition with
  | None -> Ok ()
  | Some p when Pokedex_entry.number_of species p.species = None ->
      unknown condition p.species
  | Some _ -> Ok ()

let answer ~seen = function
  | Ok (Pokedex_entry.(Seen | Caught) as e) -> (Pokedex_entry.entry_name e, seen)
  | Ok Not_seen -> ("not seen", not seen)
  | Error cause ->
      ( "not read ("
        ^ Pokemon_engine.Failure.cause_to_string cause
        ^ "), so not skipped",
        false )

let read_pokedex ~log condition p =
  let what, holds =
    answer ~seen:p.seen (Pokedex_entry_steps.read ~log p.species)
  in
  log (Printf.sprintf "[Skip] %s: %s." condition what);
  holds

let holds ~log condition =
  match pokedex_condition condition with
  | Some p -> read_pokedex ~log condition p
  | None -> false

let remembered read =
  let answers = Hashtbl.create 4 in
  fun condition ->
    match Hashtbl.find_opt answers condition with
    | Some holds -> holds
    | None ->
        let holds = read condition in
        Hashtbl.replace answers condition holds;
        holds

let read_once ~log = remembered (holds ~log)
