type layer = { name : string; pattern : string list }
type family = { layer : string; var : string; members : string list }

type t = {
  roots : string list;
  skip_dirs : string list;
  test_dirs : string list;
  library_dir : string;
  exceptions_file : string option;
  no_exceptions_roots : string list;
  max_function_lines : int;
  max_function_avg_depth : float;
  max_function_depth : int;
  max_file_avg_depth : float;
  max_file_lines : int;
  max_interface_lines : int;
  complexity_advisory : int;
  layers : layer list;
  allowed : (string * string list) list;
  families : family list;
}

let default =
  {
    roots = [];
    skip_dirs = [];
    test_dirs = [];
    library_dir = "lib";
    exceptions_file = None;
    no_exceptions_roots = [];
    max_function_lines = 50;
    max_function_avg_depth = 3.0;
    max_function_depth = 5;
    max_file_avg_depth = 2.5;
    max_file_lines = 300;
    max_interface_lines = 300;
    complexity_advisory = 10;
    layers = [];
    allowed = [];
    families = [];
  }

let words line =
  String.split_on_char ' ' line
  |> List.concat_map (String.split_on_char '\t')
  |> List.filter (fun w -> w <> "")

let int_value key v =
  match int_of_string_opt v with
  | Some n -> Ok n
  | None -> Error (Printf.sprintf "%s: '%s' is not an integer" key v)

let float_value key v =
  match float_of_string_opt v with
  | Some f -> Ok f
  | None -> Error (Printf.sprintf "%s: '%s' is not a number" key v)

let set_threshold c key v =
  let ( let* ) = Result.bind in
  match key with
  | "max_function_lines" ->
      let* n = int_value key v in
      Ok { c with max_function_lines = n }
  | "max_function_avg_depth" ->
      let* f = float_value key v in
      Ok { c with max_function_avg_depth = f }
  | "max_function_depth" ->
      let* n = int_value key v in
      Ok { c with max_function_depth = n }
  | "max_file_avg_depth" ->
      let* f = float_value key v in
      Ok { c with max_file_avg_depth = f }
  | "max_file_lines" ->
      let* n = int_value key v in
      Ok { c with max_file_lines = n }
  | "max_interface_lines" ->
      let* n = int_value key v in
      Ok { c with max_interface_lines = n }
  | "complexity_advisory" ->
      let* n = int_value key v in
      Ok { c with complexity_advisory = n }
  | _ -> Error (Printf.sprintf "unknown key '%s'" key)

let apply_line c = function
  | [ "root"; dir ] -> Ok { c with roots = c.roots @ [ dir ] }
  | [ "skip_dir"; name ] -> Ok { c with skip_dirs = c.skip_dirs @ [ name ] }
  | [ "test_dir"; name ] -> Ok { c with test_dirs = c.test_dirs @ [ name ] }
  | [ "library_dir"; name ] -> Ok { c with library_dir = name }
  | [ "exceptions"; file ] -> Ok { c with exceptions_file = Some file }
  | [ "no_exceptions"; dir ] ->
      Ok { c with no_exceptions_roots = c.no_exceptions_roots @ [ dir ] }
  | [ "layer"; name; pattern ] ->
      let layer = { name; pattern = String.split_on_char '/' pattern } in
      Ok { c with layers = c.layers @ [ layer ] }
  | "allow" :: name :: deps ->
      Ok { c with allowed = c.allowed @ [ (name, deps) ] }
  | "family" :: layer :: var :: members ->
      Ok { c with families = c.families @ [ { layer; var; members } ] }
  | [ key; v ] -> set_threshold c key v
  | key :: _ -> Error (Printf.sprintf "malformed '%s' line" key)
  | [] -> Ok c

let check_layer_names c =
  let declared name = List.exists (fun l -> l.name = name) c.layers in
  let undeclared =
    List.concat_map (fun (name, deps) -> name :: deps) c.allowed
    @ List.map (fun (f : family) -> f.layer) c.families
    |> List.filter (fun n -> n <> "*" && not (declared n))
  in
  match (c.roots, undeclared) with
  | [], _ -> Error "no 'root' line"
  | _, n :: _ ->
      Error (Printf.sprintf "allow or family names undeclared layer '%s'" n)
  | _, [] -> Ok c

let apply_text_line c line =
  let trimmed = String.trim line in
  if trimmed = "" || trimmed.[0] = '#' then Ok c
  else apply_line c (words trimmed)

let parse text =
  let step (result, lineno) line =
    let located e = Printf.sprintf "line %d: %s" lineno e in
    let next c = Result.map_error located (apply_text_line c line) in
    (Result.bind result next, lineno + 1)
  in
  let result, _ =
    List.fold_left step (Ok default, 1) (String.split_on_char '\n' text)
  in
  Result.bind result check_layer_names
