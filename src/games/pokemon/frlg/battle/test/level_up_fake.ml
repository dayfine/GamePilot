(* Fake Level_up game steps for the tests of Level_up and of what runs it
   (scripted battles): it answers each step from a script and records the
   steps. *)

open Frlg_battle

(* The fake game: the looks [next] answers in order, the list each opened
   list shows in order, how each evolution scene leaves off; [trace] is every
   step it saw taken (newest first), [logs] every line logged. Its steps
   serve any context; [Back] is wherever the context ends. *)
type game = {
  mutable looks : Level_up.look list;
  mutable lists : Level_up.forget_list list;
  mutable scenes : Level_up.scene list;
  mutable trace : string list;
  mutable logs : string list;
}

let game ?(lists = []) ?(scenes = []) looks =
  { looks; lists; scenes; trace = []; logs = [] }

let note g s = g.trace <- s :: g.trace

let pop_look g () : Level_up.look =
  match g.looks with
  | [] -> Timed_out
  | l :: rest ->
      g.looks <- rest;
      l

let pop_list g () : Level_up.forget_list =
  match g.lists with
  | [] -> { offered = None; known = [] }
  | l :: rest ->
      g.lists <- rest;
      l

(* How a scene left off: the next scripted one, else it goes on when a
   question, the list or more of the scene comes next. *)
let scene_after g : Level_up.scene =
  match (g.scenes, g.looks) with
  | s :: rest, _ ->
      g.scenes <- rest;
      s
  | [], (Move_prompt | Forget_list | Evolving _) :: _ -> Continues
  | [], _ -> Ended

let noted g step result () =
  note g step;
  result

let fake_game_steps g : Level_up.game_steps =
  {
    next = pop_look g;
    open_list = noted g "yes" true;
    read_list = pop_list g;
    forget = (fun row -> noted g (Printf.sprintf "forget %d" row) true ());
    leave_list = noted g "leave" true;
    decline = noted g "no" true;
    evolution =
      (fun ~cancel ->
        note g (if cancel then "hold B" else "wait");
        scene_after g);
    log = (fun line -> g.logs <- line :: g.logs);
  }

let known = [ Some "lick"; Some "hypnosis"; Some "spite"; Some "curse" ]
let offer move : Level_up.forget_list = { offered = Some move; known }

let rule learn replacing : Level_up_policy.move_rule =
  { learn; replacing = Named replacing }

let slot_rule learn slot : Level_up_policy.move_rule =
  { learn; replacing = Slot slot }

let policy ?(rules = []) ?(evolve = false) () : Level_up_policy.policy =
  { rules; evolve }

let traced g text = text ^ " [" ^ String.concat ", " (List.rev g.trace) ^ "]"
let stats = Level_up.Stats None
let evolving = Level_up.Evolving None
let gastly : Level_up.member = { slot = 1; species = "gastly"; nickname = None }
