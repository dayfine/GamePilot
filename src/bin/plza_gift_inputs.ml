(* What PLZA's gift programs read at the edge, so that neither reads a clock
   or a file itself: the gift catalog (gifts.json, Plza_gift_catalog), today's
   date (the host's, UTC), which plza.claim-gifts and pokemon_home.bank-plza both
   compare each gift's last day with, and the Internet gifts' name templates
   in the run's language. Claim-gifts gets all three
   (Plza_claim_gifts_series.Claim_gifts_runs.inputs), bank-home the catalog
   and the date (Plza_bank_home.Catalog_moves); the guide's gifts block is
   the catalog's table. *)

module C = Plza_gift_catalog.Gift_catalog
module D = Plza_gift_catalog.Gift_catalog_decode

let ( let* ) = Result.bind

let catalog () =
  match Repo_io.Repo_files.locate D.path with
  | None -> Error (D.path ^ " not found from here: run in the repo")
  | Some file -> Result.bind (Repo_io.Json_file.read file) D.of_json

(* The host's day in UTC. *)
let today () =
  let t = Unix.gmtime (Unix.time ()) in
  { C.year = t.tm_year + 1900; month = t.tm_mon + 1; day = t.tm_mday }

let read_file path = In_channel.with_open_bin path In_channel.input_all

(* Each Internet gift's name template that exists in [language], as PNG
   bytes, by gift id. *)
let name_templates ~language catalog =
  List.filter_map
    (fun (g : C.gift) ->
      let path =
        Plza_claim_gifts.Live_gift_steps.name_template ~id:g.id ~language
      in
      match (g.how, Repo_io.Repo_files.locate path) with
      | Internet, Some file -> Some (g.id, read_file file)
      | _ -> None)
    catalog

let default_language = "en"

let inputs options :
    (Plza_claim_gifts_series.Claim_gifts_runs.inputs, string) result =
  let* catalog = catalog () in
  let language =
    Option.value ~default:default_language (Run_options.find options "language")
  in
  Ok
    {
      Plza_claim_gifts_series.Claim_gifts_runs.catalog;
      today = today ();
      name_templates = name_templates ~language catalog;
    }

let gifts_block () = Result.map C.guide_table (catalog ())
