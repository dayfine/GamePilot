type entry = {
  time : string;
  game : string;
  run : string;
  checkpoint : string;
  mode : string;
  result : string;
  at : string;
  reason : string;
}

let default_limit = 200

let checkpoint_games =
  lazy
    (List.concat_map
       (fun (p : Program_registry.t) ->
         List.map (fun cp -> (cp, p.game.game_id)) (Ui_api.checkpoints_of p))
       Program_registry.all)

let infer_game checkpoint =
  match String.index_opt checkpoint '.' with
  | Some i when i > 0 -> String.sub checkpoint 0 i
  | _ -> (
      match List.assoc_opt checkpoint (Lazy.force checkpoint_games) with
      | Some g -> g
      | None -> "")

let field_at cols i =
  match List.nth_opt cols i with Some s -> String.trim s | None -> ""

let make_entry time run checkpoint mode result rest =
  let cp = String.trim checkpoint in
  {
    time = String.trim time;
    game = infer_game cp;
    run = String.trim run;
    checkpoint = cp;
    mode = String.trim mode;
    result = String.trim result;
    at = field_at rest 0;
    reason = field_at rest 1;
  }

let entry_of_cols = function
  | time :: run :: checkpoint :: mode :: result :: rest ->
      Some (make_entry time run checkpoint mode result rest)
  | _ -> None

let parse_row line =
  let trimmed = String.trim line in
  if trimmed = "" || String.starts_with ~prefix:"time\t" trimmed then None
  else entry_of_cols (String.split_on_char '\t' line)

let take n xs =
  let rec go acc k = function
    | [] -> List.rev acc
    | _ when k <= 0 -> List.rev acc
    | x :: rest -> go (x :: acc) (k - 1) rest
  in
  go [] n xs

let parse_tsv ?(limit = default_limit) text =
  String.split_on_char '\n' text
  |> List.filter_map parse_row |> List.rev |> take limit

let load ?(limit = default_limit) ~runs_dir () =
  let path = Filename.concat runs_dir "RESULTS.tsv" in
  if not (Sys.file_exists path) then []
  else
    let text = In_channel.with_open_text path In_channel.input_all in
    parse_tsv ~limit text

let entry_to_json e =
  `Assoc
    [
      ("time", `String e.time);
      ("game", `String e.game);
      ("run", `String e.run);
      ("checkpoint", `String e.checkpoint);
      ("mode", `String e.mode);
      ("result", `String e.result);
      ("at", `String e.at);
      ("reason", `String e.reason);
    ]

let to_json ~runs_dir entries =
  `Assoc
    [
      ("runs_dir", `String runs_dir);
      ("entries", `List (List.map entry_to_json entries));
    ]
