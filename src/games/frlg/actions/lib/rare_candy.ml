type look =
  | Level_up
  | Move_prompt
  | Forget_list
  | Evolving
  | In_bag
  | Timed_out

type forget_list = { offered : string option; known : string option list }
type opened = Opened | No_candy | Not_opened of string

type rig = {
  open_candy : slot:int -> opened;
  next : unit -> look;
  open_list : unit -> bool;
  read_list : unit -> forget_list;
  forget : int -> bool;
  leave_list : unit -> bool;
  decline : unit -> bool;
  evolution : cancel:bool -> unit;
  close_bag : unit -> unit;
  log : string -> unit;
}

type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  levelled : bool;
  learned : Candy_plan.move_rule list;
  declined : string option list;
  evolution : evolution;
}

type result = Used of outcome | Out_of_candies | Failed of string

let max_looks = 40

exception Stopped of string

let stop why = raise (Stopped why)

(* One candy under way: what it has seen and answered. *)
type under_way = {
  rig : rig;
  use : Candy_plan.use;
  mutable levelled : bool;
  mutable learned : Candy_plan.move_rule list;
  mutable declined : string option list;
  mutable evolution : evolution;
}

let move_name = Option.value ~default:"an unread move"

let declined r offered =
  r.declined <- r.declined @ [ offered ];
  r.rig.log ("Rare Candy: declined " ^ move_name offered ^ ".")

let leave r offered why =
  r.rig.log ("Rare Candy: " ^ why ^ ".");
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

let learn r (rule : Candy_plan.move_rule) known =
  match row_of known rule.replacing with
  | None ->
      leave r (Some rule.learn)
        (Printf.sprintf "%s does not read among the known moves" rule.replacing)
  | Some row ->
      if not (r.rig.forget row) then
        stop (Printf.sprintf "the list's cursor did not read on move %d" row);
      r.learned <- r.learned @ [ rule ];
      r.rig.log
        (Printf.sprintf "Rare Candy: learned %s over %s." rule.learn
           rule.replacing)

let on_list r =
  let { offered; known } = r.rig.read_list () in
  match offered with
  | None -> leave r None "the move offered did not read"
  | Some move -> (
      match Candy_plan.rule_for r.use.rules ~offered:move with
      | Some rule -> learn r rule known
      | None -> leave r offered ("no rule learns " ^ move))

let prompt r =
  if r.use.rules = [] then (
    if not (r.rig.decline ()) then stop "no \"Stop trying to teach?\"";
    declined r None)
  else if r.rig.open_list () then on_list r
  else stop "the list to forget from did not show"

(* The first scene decides; the scene shows again after a prompt it asks
   and while "stopped evolving" prints, and is then only waited out. *)
let evolving r =
  match r.evolution with
  | No_evolution when r.use.evolve ->
      r.evolution <- Evolved;
      r.rig.log "Rare Candy: evolving, let it run.";
      r.rig.evolution ~cancel:false
  | No_evolution ->
      r.evolution <- Cancelled;
      r.rig.log "Rare Candy: evolving, cancelled with B.";
      r.rig.evolution ~cancel:true
  | Evolved | Cancelled -> r.rig.evolution ~cancel:false

let rec answer r looks =
  if looks >= max_looks then
    stop (Printf.sprintf "still not back in the bag after %d looks" max_looks);
  match r.rig.next () with
  | In_bag -> ()
  | Timed_out -> stop "nothing to answer showed"
  | Level_up ->
      r.levelled <- true;
      answer r (looks + 1)
  | Move_prompt ->
      prompt r;
      answer r (looks + 1)
  | Forget_list ->
      on_list r;
      answer r (looks + 1)
  | Evolving ->
      evolving r;
      answer r (looks + 1)

let outcome r =
  {
    levelled = r.levelled;
    learned = r.learned;
    declined = r.declined;
    evolution = r.evolution;
  }

let used rig use =
  let r =
    {
      rig;
      use;
      levelled = false;
      learned = [];
      declined = [];
      evolution = No_evolution;
    }
  in
  match answer r 0 with
  | () ->
      rig.close_bag ();
      Used (outcome r)
  | exception Stopped why -> Failed why

let run rig (use : Candy_plan.use) ~slot =
  rig.log (Printf.sprintf "Rare Candy: one on slot %d." slot);
  match rig.open_candy ~slot with
  | No_candy -> Out_of_candies
  | Not_opened why -> Failed why
  | Opened -> used rig use

let evolution_name = function
  | No_evolution -> "none"
  | Evolved -> "evolved"
  | Cancelled -> "cancelled"

let describe_outcome (o : outcome) =
  Printf.sprintf "%s; learned %s; declined %s; evolution %s"
    (if o.levelled then "levelled up" else "no effect")
    (match o.learned with
    | [] -> "none"
    | l ->
        String.concat ", "
          (List.map (fun (m : Candy_plan.move_rule) -> m.learn) l))
    (match o.declined with
    | [] -> "none"
    | l -> String.concat ", " (List.map move_name l))
    (evolution_name o.evolution)

let describe = function
  | Used o -> "Rare Candy: " ^ describe_outcome o ^ "."
  | Out_of_candies -> "Rare Candy: none left in the bag."
  | Failed why -> "Rare Candy: failed: " ^ why ^ "."
