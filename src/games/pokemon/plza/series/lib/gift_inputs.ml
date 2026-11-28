module C = Plza_gift_catalog.Gift_catalog
module D = Plza_gift_catalog.Gift_catalog_decode

let catalog () =
  match Repo_io.Repo_files.locate D.path with
  | None -> Error (D.path ^ " not found from here: run in the repo")
  | Some file -> Result.bind (Repo_io.Json_file.read file) D.of_json

let unix_tm_year_epoch = 1900

let today () =
  let t = Unix.gmtime (Unix.time ()) in
  {
    C.year = t.tm_year + unix_tm_year_epoch;
    month = t.tm_mon + 1;
    day = t.tm_mday;
  }

let read_file path = In_channel.with_open_bin path In_channel.input_all

let name_templates ~template_path ~language catalog =
  List.filter_map
    (fun (g : C.gift) ->
      let path = template_path ~id:g.id ~language in
      match (g.how, Repo_io.Repo_files.locate path) with
      | Internet, Some file -> Some (g.id, read_file file)
      | _ -> None)
    catalog

let gifts_block () = Result.map C.guide_table (catalog ())
