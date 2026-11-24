(* The selected checkpoints in order, each run until its policy decides
   (Story.Checkpoint_trials), stopping at the first that does not pass; the
   exit code. In verification mode a passing checkpoint's last passing end
   becomes the next checkpoint's start state, the one before kept beside it.
   StoryEngine::run_checkpoints() and verify_checkpoint() on the fork's
   frlg/lean; see Checkpoints_command. *)

open Story
module Run = Checkpoint_live_run

let ( let* ) = Result.bind
let plan_file ~plan_dir id = Filename.concat plan_dir (id ^ ".plan.json")

let load_plan ~plan_dir id =
  let* plan = Plan_decode.load (plan_file ~plan_dir id) in
  let* () = Frlg_story.Checkpoint_run.check_plan plan in
  Ok plan

let next_plan ~plan_dir = function
  | None -> Ok None
  | Some n ->
      Result.map (fun (p : Plan.t) -> Some p.checkpoint) (load_plan ~plan_dir n)

let start_state (setup : Run.setup) id =
  let path = Filename.concat setup.states (id ^ ".start.ss") in
  if Sys.file_exists path then Ok path else Error ("no start state " ^ path)

(* The checkpoint [id], its end declared by [next]'s plan. *)
let checkpoint ~plan_dir (setup : Run.setup) id ~next =
  let* plan = load_plan ~plan_dir id in
  let* next = next_plan ~plan_dir next in
  let* start_state = start_state setup id in
  Ok
    {
      Run.id;
      plan;
      start_state;
      end_at =
        (match plan.postconditions.position with
        | Some position -> Some position
        | None -> Checkpoint_end.declared ~next plan.checkpoint);
    }

(* Runs [cp] until the policy decides; the verdict and the runs, oldest
   first. *)
let rec runs_of setup cp runs =
  match
    Checkpoint_trials.verdict setup.Run.policy
      (List.map (fun (_, o) -> Run.trial o) runs)
  with
  | Checkpoint_trials.Run_again ->
      runs_of setup cp (runs @ [ Run.run setup cp (List.length runs + 1) ])
  | verdict -> (verdict, runs)

(* The last passing run's end.ss as [next]'s start (or [id].end.ss). *)
let keep_end (setup : Run.setup) id ~next runs =
  let target =
    match next with Some n -> n ^ ".start.ss" | None -> id ^ ".end.ss"
  in
  let dst = Filename.concat setup.states target in
  let passing = List.filter (fun (_, o) -> o = Run.Passed) runs in
  match List.rev passing with
  | [] -> ()
  | (record, _) :: _ ->
      let src = Run_record.path record "end.ss" in
      if Sys.file_exists src then (
        if Sys.file_exists dst then
          Sys.rename dst (dst ^ ".replaced-" ^ Run_record.time ());
        Run_record.copy_file ~src ~dst;
        print_endline ("[Checkpoints] saved the end as " ^ dst))
      else print_endline ("[Checkpoints] no end.ss in " ^ record.dir)

(* A capped grind's end is not the next checkpoint's start: never saved. *)
let keep_uncapped_end (setup : Run.setup) id ~next runs =
  match setup.common.grind_cap with
  | Some cap ->
      Printf.printf
        "[Checkpoints] grind capped at %d: the end is not saved as the next \
         start state\n\
         %!"
        cap
  | None -> keep_end setup id ~next runs

(* Whether [cp] passed, after running it until its policy decided. *)
let decide (setup : Run.setup) (cp : Run.checkpoint) ~next =
  match runs_of setup cp [] with
  | Checkpoint_trials.Checkpoint_passed { passes; runs }, done_runs ->
      Printf.printf "[Checkpoints] %s: passed (%d of %d runs)%s\n%!" cp.id
        passes runs (Run.capped_note setup cp);
      if setup.policy.keeps_end then
        keep_uncapped_end setup cp.id ~next done_runs;
      true
  | Checkpoint_trials.Stopped why, _ ->
      Printf.printf "[Checkpoints] %s: stopped: %s\n%!" cp.id why;
      false
  | Checkpoint_trials.Run_again, _ -> false

let one ~plan_dir setup id ~next =
  match checkpoint ~plan_dir setup id ~next with
  | Ok cp -> decide setup cp ~next
  | Error e ->
      print_endline ("[Checkpoints] " ^ id ^ ": " ^ e);
      false

let rec run ~plan_dir setup ids ~after =
  match ids with
  | [] -> 0
  | id :: rest ->
      let next = match rest with n :: _ -> Some n | [] -> after in
      if one ~plan_dir setup id ~next then run ~plan_dir setup rest ~after
      else 1
