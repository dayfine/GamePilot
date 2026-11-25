let pokedex_seen = "pokedex_seen"
let prefix = pokedex_seen ^ ":"

(* The species a pokedex_seen condition names. *)
let pokedex_species condition =
  if String.starts_with ~prefix condition then
    let n = String.length prefix in
    Some (String.sub condition n (String.length condition - n))
  else None

let unknown condition slug =
  Error
    (Printf.sprintf "skip_if %s: %s is no Kanto Pokedex species" condition slug)

let check species condition =
  match pokedex_species condition with
  | None -> Ok ()
  | Some slug when Pokedex_entry.number_of species slug = None ->
      unknown condition slug
  | Some _ -> Ok ()

let said = function
  | Ok (Pokedex_entry.(Seen | Caught) as e) -> (Pokedex_entry.entry_name e, true)
  | Ok Not_seen -> ("not seen", false)
  | Error cause ->
      ( "not read ("
        ^ Pokemon_engine.Failure.cause_to_string cause
        ^ "), so not skipped",
        false )

let seen ~log condition slug =
  let what, holds = said (Pokedex_entry_steps.read ~log slug) in
  log (Printf.sprintf "[Skip] %s: %s." condition what);
  holds

let holds ~log condition =
  match pokedex_species condition with
  | Some slug -> seen ~log condition slug
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
