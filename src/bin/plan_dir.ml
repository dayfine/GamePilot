(* A program's plan folder: its checkpoints (<ID>.plan.json, in run order),
   a range of them, and the plan before one. *)

open Engine_series
open Pokemon_engine

let plan_suffix = ".plan.json"

(* Checkpoint ids in the folder, in run order ({!Checkpoint_order}). *)
let checkpoint_ids dir =
  match Sys.readdir dir with
  | names ->
      Ok
        (Array.to_list names
        |> List.filter (fun n -> Filename.check_suffix n plan_suffix)
        |> List.map (fun n -> Filename.chop_suffix n plan_suffix)
        |> List.sort Checkpoint_order.compare)
  | exception Sys_error e -> Error e

let rec drop_until id = function
  | [] -> []
  | x :: rest as all -> if x = id then all else drop_until id rest

(* [from_id .. to_id] and the id after [to_id], if any. *)
let select ids ~from_id ~to_id =
  let from = drop_until from_id ids in
  match (from, drop_until to_id from) with
  | [], _ -> Error ("no checkpoint " ^ from_id)
  | _, [] -> Error ("no checkpoint " ^ to_id ^ " at or after " ^ from_id)
  | _, _ :: after ->
      let n = List.length from - List.length after in
      Ok (List.filteri (fun i _ -> i < n) from, List.nth_opt after 0)

let ( let* ) = Result.bind
let plan_file ~plan_dir id = Filename.concat plan_dir (id ^ plan_suffix)

let load_plan ~plan_dir id =
  let* plan = Frlg_checkpoints.Plan_file.load (plan_file ~plan_dir id) in
  let* () = Frlg_checkpoints.Checkpoint_run.check_plan plan in
  Ok plan

(* The id before [id] in the folder's order, if any. *)
let previous ids id =
  let rec go prev = function
    | [] -> None
    | x :: rest -> if x = id then prev else go (Some x) rest
  in
  go None ids

(* What the checkpoint before [id] promised: its postconditions. *)
let promised_before ~plan_dir id =
  let* ids = checkpoint_ids plan_dir in
  match previous ids id with
  | None -> Ok None
  | Some p ->
      Result.map
        (fun (plan : Plan.t) ->
          Some (Postconditions.stated plan.postconditions))
        (load_plan ~plan_dir p)
