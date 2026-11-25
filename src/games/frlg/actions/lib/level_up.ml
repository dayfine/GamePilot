module P = Level_up_policy

type who = Slot of int | Nickname of string

type look =
  | Exp of who option
  | Stats of who option
  | Move_prompt
  | Forget_list
  | Evolving of who option
  | Back
  | Timed_out

type forget_list = { offered : string option; known : string option list }
type scene = Continues | Ended

type driver = {
  next : unit -> look;
  open_list : unit -> bool;
  read_list : unit -> forget_list;
  forget : int -> bool;
  leave_list : unit -> bool;
  decline : unit -> bool;
  evolution : cancel:bool -> scene;
  log : string -> unit;
}

type member = { slot : int; species : string; nickname : string option }
type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  member : member;
  levels : int;
  learned : P.move_rule list;
  declined : string option list;
  evolution : evolution;
}

let max_looks = 200

exception Stopped of string

let stop why = raise (Stopped why)

(* A run under way: each member's outcome so far, whose screens these are,
   and whether an evolution scene is still going. *)
type under_way = {
  driver : driver;
  policies : P.t;
  members : outcome array;
  mutable current : int option;
  mutable last_scene : int option;
  mutable in_scene : bool;
}

let move_name = Option.value ~default:"an unread move"
let name (o : outcome) = Printf.sprintf "slot %d" o.member.slot
let indices r = Seq.init (Array.length r.members) Fun.id

let find_slot r s =
  match Seq.find (fun i -> r.members.(i).member.slot = s) (indices r) with
  | Some i -> i
  | None -> stop (Printf.sprintf "a screen names slot %d, not in the run" s)

(* A nickname shared by two members does not tell them apart: the order
   decides, as when no name was read, and the log says so. *)
let find_nickname r n ~or_else =
  match
    List.of_seq
      (Seq.filter (fun i -> r.members.(i).member.nickname = Some n) (indices r))
  with
  | [ i ] -> i
  | [] -> stop (Printf.sprintf "a screen names %s, not in the run" n)
  | _ ->
      r.driver.log
        (Printf.sprintf
           "Level up: %s names more than one member; going by the order." n);
      or_else ()

let named r who ~or_else =
  match who with
  | Some (Slot s) -> find_slot r s
  | Some (Nickname n) -> find_nickname r n ~or_else
  | None -> or_else ()

let current r =
  match r.current with
  | Some i -> i
  | None -> stop "a question with no member levelled before it"

let update r i f = r.members.(i) <- f r.members.(i)

let policy r i =
  let m = r.members.(i).member in
  P.for_member r.policies ~slot:m.slot ~species:m.species

let log r i fmt =
  Printf.ksprintf
    (fun s -> r.driver.log ("Level up: " ^ name r.members.(i) ^ ": " ^ s ^ "."))
    fmt

let declined r i offered =
  update r i (fun o -> { o with declined = o.declined @ [ offered ] });
  log r i "declined %s" (move_name offered)

let leave r i offered why =
  log r i "%s" why;
  if not (r.driver.leave_list ()) then
    stop "no \"Stop trying to teach?\" after the list";
  declined r i offered

let row_of known move =
  let rec find i = function
    | [] -> None
    | Some m :: _ when m = move -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 0 known

let learn r i (rule : P.move_rule) known =
  match row_of known rule.replacing with
  | None ->
      leave r i (Some rule.learn)
        (rule.replacing ^ " does not read among the known moves")
  | Some row ->
      if not (r.driver.forget row) then
        stop (Printf.sprintf "the list's cursor did not read on move %d" row);
      update r i (fun o -> { o with learned = o.learned @ [ rule ] });
      log r i "learned %s" (P.describe_rule rule)

let on_list r =
  let i = current r in
  let { offered; known } = r.driver.read_list () in
  match offered with
  | None -> leave r i None "the move offered did not read"
  | Some move -> (
      match P.rule_for (policy r i).rules ~offered:move with
      | Some rule -> learn r i rule known
      | None -> leave r i offered ("no rule learns " ^ move))

let prompt r =
  let i = current r in
  if (policy r i).rules = [] then (
    if not (r.driver.decline ()) then stop "no \"Stop trying to teach?\"";
    declined r i None)
  else if r.driver.open_list () then on_list r
  else stop "the list to forget from did not show"

(* The next member in slot order that levelled, after the last scene's. *)
let next_levelled r =
  let after = Option.value r.last_scene ~default:(-1) in
  let n = Array.length r.members in
  match
    Seq.find
      (fun i -> r.members.(i).levels > 0)
      (Seq.init (max 0 (n - after - 1)) (fun k -> after + 1 + k))
  with
  | Some i -> i
  | None -> stop "an evolution with no member left that levelled"

let next_exp r =
  match r.current with
  | None -> 0
  | Some i -> (i + 1) mod Array.length r.members

let first_or_current r = Option.value r.current ~default:0

(* A scene starts when none is going; it is decided once, by its member's
   policy, and is then only waited out. *)
let evolving r who =
  if not r.in_scene then (
    let i = named r who ~or_else:(fun () -> next_levelled r) in
    let evolve = (policy r i).evolve in
    r.current <- Some i;
    r.last_scene <- Some i;
    update r i (fun o ->
        { o with evolution = (if evolve then Evolved else Cancelled) });
    log r i "evolving, %s" (if evolve then "let it run" else "cancelled with B");
    r.in_scene <- r.driver.evolution ~cancel:(not evolve) = Continues)
  else r.in_scene <- r.driver.evolution ~cancel:false = Continues

let answer_look r = function
  | Exp who -> r.current <- Some (named r who ~or_else:(fun () -> next_exp r))
  | Stats who ->
      let i = named r who ~or_else:(fun () -> first_or_current r) in
      r.current <- Some i;
      update r i (fun o -> { o with levels = o.levels + 1 });
      log r i "level %d of this run" r.members.(i).levels
  | Move_prompt -> prompt r
  | Forget_list -> on_list r
  | Evolving who -> evolving r who
  | Back | Timed_out -> ()

let rec answer r looks =
  if looks >= max_looks then
    stop (Printf.sprintf "still not back after %d looks" max_looks);
  match r.driver.next () with
  | Back -> ()
  | Timed_out -> stop "nothing to answer showed"
  | look ->
      answer_look r look;
      answer r (looks + 1)

let start member =
  { member; levels = 0; learned = []; declined = []; evolution = No_evolution }

let run driver policies ~members =
  let r =
    {
      driver;
      policies;
      members = Array.of_list (List.map start members);
      current = None;
      last_scene = None;
      in_scene = false;
    }
  in
  if members = [] then Error "no member to level"
  else
    match answer r 0 with
    | () -> Ok (Array.to_list r.members)
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
    (names_or_none (fun (r : P.move_rule) -> r.learn) o.learned)
    (names_or_none move_name o.declined)
    (evolution_name o.evolution)
