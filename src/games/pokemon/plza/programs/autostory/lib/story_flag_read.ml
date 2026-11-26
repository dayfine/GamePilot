module S = Plza_story.Steps
module Visit = Plza_story.Main_menu_visit

let ( let* ) = Result.bind
let no_menu = Engine_run.Failure.cause "main_menu_unread" "no main menu to read"

(* The main menu opened, its Link Play row read, the menu closed. *)
let link_play steps ~checkpoint_id =
  let log line =
    steps.S.log_detail
      (Printf.sprintf "[Checkpoint] %s: mystery_gift: %s" checkpoint_id line)
  in
  let* () = Visit.enter steps ~log in
  let shown = steps.S.read_link_play_row () in
  let* () = Visit.leave steps in
  Option.to_result ~none:no_menu shown

let read_line flag = function
  | Ok true -> flag ^ " set (the main menu shows Link Play)"
  | Ok false -> flag ^ " clear (the main menu has no Link Play row)"
  | Error _ -> flag

let log_read steps ~checkpoint_id flag read =
  let verdict =
    match read with Ok _ -> "FLAG READ" | Error _ -> "FLAG UNREAD"
  in
  let why =
    match read with
    | Error cause -> ": " ^ Engine_run.Failure.cause_to_string cause
    | Ok _ -> ""
  in
  steps.S.log
    (Printf.sprintf "[Checkpoint] %s: %s: %s%s" checkpoint_id verdict
       (read_line flag read) why)

let read_one steps ~checkpoint_id flag =
  match flag with
  | "mystery_gift" ->
      let read = link_play steps ~checkpoint_id in
      log_read steps ~checkpoint_id flag read;
      Result.to_option (Result.map (fun set -> (flag, set)) read)
  | _ -> None

let read steps ~checkpoint_id flags =
  List.filter_map (read_one steps ~checkpoint_id) flags
