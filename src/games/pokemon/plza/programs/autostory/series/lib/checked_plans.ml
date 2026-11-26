module P = Plza_engine
module Story = Plza_autostory

let ( let* ) = Result.bind

let load_plan ~plan_dir id =
  P.Plan_decode.load (Engine_series.Plan_folder.plan_file ~plan_dir id)

(* The checkpoint after [id] in the folder's run order, if any. *)
let rec next_id id = function
  | a :: (b :: _ as rest) -> if a = id then Some b else next_id id rest
  | [ _ ] | [] -> None

(* The plan with its end place resolved (Start_signature.promised_end): the
   next checkpoint's start signature when it names none, as FireRed's end is
   the next start. *)
let with_end ~plan_dir ~all (plan : P.Plan.t) =
  let* next =
    match next_id plan.checkpoint.checkpoint_id all with
    | None -> Ok None
    | Some n -> Result.map Option.some (load_plan ~plan_dir n)
  in
  let* ends =
    Result.map_error Engine_run.Failure.cause_to_string
      (Story.Start_signature.promised_end ~next plan)
  in
  Ok { plan with postconditions = Some ends }

(* Every plan of the series, loaded and checked (Plan_check) before the
   console moves, with its end place. *)
let load ~plan_dir ~all ids =
  List.fold_left
    (fun plans id ->
      let* plans = plans in
      let* plan = load_plan ~plan_dir id in
      let* () = Story.Plan_check.check plan in
      let* plan = with_end ~plan_dir ~all plan in
      Ok (plans @ [ plan ]))
    (Ok []) ids
