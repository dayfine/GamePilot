type move_rule = { learn : string; replacing : string }
type policy = { rules : move_rule list; evolve : bool }

let rule_for rules ~offered = List.find_opt (fun r -> r.learn = offered) rules
let describe_rule r = r.learn ^ " over " ^ r.replacing

type look = Stats | Move_prompt | Forget_list | Evolving | Back | Timed_out
type forget_list = { offered : string option; known : string option list }

type rig = {
  next : unit -> look;
  open_list : unit -> bool;
  read_list : unit -> forget_list;
  forget : int -> bool;
  leave_list : unit -> bool;
  decline : unit -> bool;
  evolution : cancel:bool -> unit;
  log : string -> unit;
}

type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  levels : int;
  learned : move_rule list;
  declined : string option list;
  evolution : evolution;
}

let max_looks = 40

exception Stopped of string

let stop why = raise (Stopped why)

(* A run under way: what it has seen and answered. *)
type under_way = {
  rig : rig;
  policy : policy;
  mutable levels : int;
  mutable learned : move_rule list;
  mutable declined : string option list;
  mutable evolution : evolution;
}

let move_name = Option.value ~default:"an unread move"

let declined r offered =
  r.declined <- r.declined @ [ offered ];
  r.rig.log ("Level up: declined " ^ move_name offered ^ ".")

let leave r offered why =
  r.rig.log ("Level up: " ^ why ^ ".");
  if not (r.rig.leave_list ()) then
    stop "no \"Stop trying to teach?\" after the list";
  declined r offered

let row_of known move =
  let rec find i = function
    | [] -> None
    | Some m :: _ when m = move -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 0 known

let learn r rule known =
  match row_of known rule.replacing with
  | None ->
      leave r (Some rule.learn)
        (Printf.sprintf "%s does not read among the known moves" rule.replacing)
  | Some row ->
      if not (r.rig.forget row) then
        stop (Printf.sprintf "the list's cursor did not read on move %d" row);
      r.learned <- r.learned @ [ rule ];
      r.rig.log ("Level up: learned " ^ describe_rule rule ^ ".")

let on_list r =
  let { offered; known } = r.rig.read_list () in
  match offered with
  | None -> leave r None "the move offered did not read"
  | Some move -> (
      match rule_for r.policy.rules ~offered:move with
      | Some rule -> learn r rule known
      | None -> leave r offered ("no rule learns " ^ move))

let prompt r =
  if r.policy.rules = [] then (
    if not (r.rig.decline ()) then stop "no \"Stop trying to teach?\"";
    declined r None)
  else if r.rig.open_list () then on_list r
  else stop "the list to forget from did not show"

(* The first scene decides; the scene shows again after a prompt it asks
   and while "stopped evolving" prints, and is then only waited out. *)
let evolving r =
  match r.evolution with
  | No_evolution when r.policy.evolve ->
      r.evolution <- Evolved;
      r.rig.log "Level up: evolving, let it run.";
      r.rig.evolution ~cancel:false
  | No_evolution ->
      r.evolution <- Cancelled;
      r.rig.log "Level up: evolving, cancelled with B.";
      r.rig.evolution ~cancel:true
  | Evolved | Cancelled -> r.rig.evolution ~cancel:false

let answer_look r = function
  | Stats ->
      r.levels <- r.levels + 1;
      r.rig.log (Printf.sprintf "Level up: level %d of this run." r.levels)
  | Move_prompt -> prompt r
  | Forget_list -> on_list r
  | Evolving -> evolving r
  | Back | Timed_out -> ()

let rec answer r looks =
  if looks >= max_looks then
    stop (Printf.sprintf "still not back after %d looks" max_looks);
  match r.rig.next () with
  | Back -> ()
  | Timed_out -> stop "nothing to answer showed"
  | look ->
      answer_look r look;
      answer r (looks + 1)

let run rig policy =
  let r =
    {
      rig;
      policy;
      levels = 0;
      learned = [];
      declined = [];
      evolution = No_evolution;
    }
  in
  match answer r 0 with
  | () ->
      Ok
        {
          levels = r.levels;
          learned = r.learned;
          declined = r.declined;
          evolution = r.evolution;
        }
  | exception Stopped why -> Error why

let evolution_name = function
  | No_evolution -> "none"
  | Evolved -> "evolved"
  | Cancelled -> "cancelled"

let names_or_none f = function
  | [] -> "none"
  | l -> String.concat ", " (List.map f l)

let describe (o : outcome) =
  Printf.sprintf "%d level%s; learned %s; declined %s; evolution %s" o.levels
    (if o.levels = 1 then "" else "s")
    (names_or_none (fun r -> r.learn) o.learned)
    (names_or_none move_name o.declined)
    (evolution_name o.evolution)
