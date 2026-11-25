open Checkpoints_plan

type t = { first : int; last : int option }

let index_of events name =
  let count = List.length events in
  match int_of_string_opt name with
  | Some n when n >= 1 && n <= count -> Ok (n - 1)
  | Some n ->
      Error (Printf.sprintf "no event #%d (the checkpoint has %d)" n count)
  | None -> (
      match List.find_index (fun (e : Plan.event) -> e.id = name) events with
      | Some i -> Ok i
      | None -> Error ("no event " ^ name ^ " in the checkpoint"))

let ( let* ) = Result.bind

let ordered ~first ~last name ~from_event =
  if last < first then
    Error ("--to-event " ^ name ^ " comes before --from-event " ^ from_event)
  else Ok { first; last = Some last }

let resolve events ~from_event ~to_event =
  let* first = index_of events from_event in
  match to_event with
  | None -> Ok { first; last = None }
  | Some name ->
      let* last = index_of events name in
      ordered ~first ~last name ~from_event

let within t i =
  i >= t.first && match t.last with None -> true | Some l -> i <= l

let select t events =
  List.filteri (fun i _ -> within t i) (List.mapi (fun i e -> (i, e)) events)

let last_index t events = Option.value t.last ~default:(List.length events - 1)
let reaches_end t events = last_index t events >= List.length events - 1

let label events index =
  let e : Plan.event = List.nth events index in
  Printf.sprintf "#%d %s" (index + 1) e.id

let describe t events =
  (label events t.first, label events (last_index t events))

let mode_name = "from-event"

let check ~mode ~keeps_states ~checkpoints =
  match (mode, keeps_states) with
  | Checkpoint_trials.Verification, _ ->
      Error
        "--from-event runs part of a checkpoint, so it never verifies one: use \
         --mode testing"
  | Testing, false ->
      Error
        "--from-event starts from a save state kept at the event, and the \
         Switch has no save states: run the checkpoint from the game's save, \
         or --from-event on mGBA (run/run_checkpoints_on_mgba.sh)"
  | Testing, true when checkpoints <> 1 ->
      Error "--from-event runs one checkpoint: give --to the same as --from"
  | Testing, true -> Ok ()

let keeps_end range (policy : Checkpoint_trials.policy) =
  Option.is_none range && policy.keeps_end
