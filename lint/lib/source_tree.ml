let skipped (c : Config.t) name =
  name = "_build"
  || (String.length name > 0 && name.[0] = '.')
  || List.mem name c.skip_dirs

let rec walk c dir acc =
  Sys.readdir dir |> Array.to_list |> List.fold_left (add_entry c dir) acc

and add_entry c dir acc entry =
  let path = Filename.concat dir entry in
  if not (Sys.is_directory path) then path :: acc
  else if skipped c entry then acc
  else walk c path acc

let files (c : Config.t) =
  match List.find_opt (fun r -> not (Sys.file_exists r)) c.roots with
  | Some missing -> Error (Printf.sprintf "root '%s' does not exist" missing)
  | None ->
      let all = List.fold_left (fun acc r -> walk c r acc) [] c.roots in
      Ok (List.sort String.compare all)

let in_test_dir (c : Config.t) path =
  String.split_on_char '/' path |> List.exists (fun s -> List.mem s c.test_dirs)

let in_library_dir (c : Config.t) path =
  Filename.basename (Filename.dirname path) = c.library_dir

let read path = In_channel.with_open_bin path In_channel.input_all
