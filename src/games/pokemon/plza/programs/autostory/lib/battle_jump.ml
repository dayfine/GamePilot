module Plan = Plza_checkpoints.Plan

type t = {
  checkpoint : Plan.checkpoint;
  log : string -> unit;
  mutable target : Plan.event option;
}

let story_battle = "story_battle"
let make checkpoint ~log = { checkpoint; log; target = None }

(* The events after [event], in order. *)
let after_event t (event : Plan.event) =
  let rec drop = function
    | [] -> []
    | (e : Plan.event) :: rest -> if e.id = event.id then rest else drop rest
  in
  drop t.checkpoint.events

let is_battle (e : Plan.event) = e.way = Some story_battle
let battle_ahead t event = List.exists is_battle (after_event t event)

(* The events from after [event] to the next story battle: the skipped ones,
   then the battle. *)
let rec to_battle skipped = function
  | [] -> None
  | (e : Plan.event) :: rest ->
      if is_battle e then Some (List.rev skipped, e)
      else to_battle (e :: skipped) rest

let jump_line t (event : Plan.event) (to_ : Plan.event) skipped =
  Printf.sprintf "[Event] %s: battle on screen during %s: jumping to %s%s"
    t.checkpoint.checkpoint_id event.id to_.id
    (match skipped with
    | [] -> ""
    | es ->
        ", skipping "
        ^ String.concat ", " (List.map (fun (e : Plan.event) -> e.id) es))

let after t event (outcome : (unit, Engine_run.Failure.cause) result) =
  match (outcome, to_battle [] (after_event t event)) with
  | Error { code = "battle_on_screen"; _ }, Some (skipped, battle) ->
      t.log (jump_line t event battle skipped);
      t.target <- Some battle;
      Ok ()
  | _ -> outcome

(* The event's place in the checkpoint. *)
let index t (event : Plan.event) =
  let rec find i = function
    | [] -> None
    | (e : Plan.event) :: rest ->
        if e.id = event.id then Some i else find (i + 1) rest
  in
  find 0 t.checkpoint.events

(* Before the battle's event: passed during the jump. The battle's event, or
   one after it (the battle skipped by its skip_if), ends the jump. *)
let before_target t event target =
  match (index t event, index t target) with
  | Some i, Some j -> i < j
  | _ -> false

let run t (event : Plan.event) handle =
  match t.target with
  | Some target when before_target t event target -> Ok ()
  | Some _ ->
      t.target <- None;
      handle ()
  | None -> handle ()
