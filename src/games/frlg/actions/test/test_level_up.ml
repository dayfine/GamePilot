(* Level_up's decisions on a fake rig that answers each step from a script
   and records the steps: one member's level-ups, and six members levelled by
   one battle. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }

(* The fake game: the looks [next] answers in order, the list each opened
   list shows in order. Its rig serves any context; [Back] is wherever the
   context ends. *)
type game = {
  mutable looks : Level_up.look list;
  mutable lists : Level_up.forget_list list;
  mutable scenes : Level_up.scene list;
  mutable trace : string list;
}

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

let level_up_rig g : Level_up.rig =
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
    log = ignore;
  }

let known = [ Some "lick"; Some "hypnosis"; Some "spite"; Some "curse" ]
let offer move : Level_up.forget_list = { offered = Some move; known }
let rule learn replacing : Level_up_policy.move_rule = { learn; replacing }

let policy ?(rules = []) ?(evolve = false) () : Level_up_policy.policy =
  { rules; evolve }

let traced g text = text ^ " [" ^ String.concat ", " (List.rev g.trace) ^ "]"
let stats = Level_up.Stats None
let evolving = Level_up.Evolving None
let gastly : Level_up.member = { slot = 1; species = "gastly" }

let settle ?(lists = []) looks policy () =
  let g = { looks; lists; scenes = []; trace = [] } in
  traced g
    (match
       Level_up.run (level_up_rig g)
         (Level_up_policy.only policy)
         ~members:[ gastly ]
     with
    | Ok outcomes -> String.concat "; " (List.map Level_up.describe outcomes)
    | Error why -> "failed: " ^ why)

let mean_look = [ rule "mean-look" "lick" ]

let level_ups =
  [
    case "a level, nothing more"
      (settle [ stats; Back ] (policy ()))
      "1 level; learned none; declined none; evolution none []";
    case "a move learned over the rule's move"
      (settle
         ~lists:[ offer "mean-look" ]
         [ stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined none; evolution none [yes, forget \
       0]";
    case "no rules: declined at the prompt"
      (settle [ stats; Move_prompt; Back ] (policy ()))
      "1 level; learned none; declined an unread move; evolution none [no]";
    case "a move no rule names: the list left"
      (settle
         ~lists:[ offer "night-shade" ]
         [ stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned none; declined night-shade; evolution none [yes, leave]";
    case "two moves at one level: one learned, one declined"
      (settle
         ~lists:[ offer "night-shade"; offer "mean-look" ]
         [ stats; Move_prompt; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined night-shade; evolution none [yes, \
       leave, yes, forget 0]";
    case "two levels in a row, each with its prompt (a battle's shape)"
      (settle
         ~lists:[ offer "night-shade"; offer "mean-look" ]
         [ stats; Move_prompt; stats; Move_prompt; evolving; Back ]
         (policy ~rules:mean_look ~evolve:true ()))
      "2 levels; learned mean-look; declined night-shade; evolution evolved \
       [yes, leave, yes, forget 0, wait]";
    case "the rule's move to replace not known: declined"
      (settle
         ~lists:[ offer "spore" ]
         [ stats; Move_prompt; Back ]
         (policy ~rules:[ rule "spore" "scratch" ] ()))
      "1 level; learned none; declined spore; evolution none [yes, leave]";
    case "the offered move unread: the list left"
      (settle
         ~lists:[ { offered = None; known } ]
         [ stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned none; declined an unread move; evolution none [yes, \
       leave]";
    case "a list opened by a stray A"
      (settle
         ~lists:[ offer "mean-look" ]
         [ stats; Forget_list; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined none; evolution none [forget 0]";
    case "an evolution let run, then its move asked"
      (settle
         ~lists:[ offer "mean-look" ]
         [ stats; evolving; Move_prompt; evolving; Back ]
         (policy ~rules:mean_look ~evolve:true ()))
      "1 level; learned mean-look; declined none; evolution evolved [wait, \
       yes, forget 0, wait]";
    case "an evolution cancelled once, then waited out"
      (settle [ stats; evolving; evolving; Back ] (policy ()))
      "1 level; learned none; declined none; evolution cancelled [hold B, wait]";
    case "nothing shows"
      (settle [ stats ] (policy ()))
      "failed: nothing to answer showed []";
  ]

(* A battle's shape: six members, each switched in once, so all gain EXP,
   all level (several levels each) and all evolve; names unread, so the run
   tracks them by order. Slot 2 cancels its evolution, the Squirtle learns
   Bite over Tail Whip, slot 4 has a rule that its move does not match and
   declines it; the rest decline at the prompt. *)
let party =
  List.mapi
    (fun i species : Level_up.member -> { slot = i + 1; species })
    [ "bulbasaur"; "charmander"; "squirtle"; "caterpie"; "weedle"; "pidgey" ]

let six_policies : Level_up_policy.t =
  {
    by_slot = [ (2, policy ()); (4, policy ~rules:mean_look ~evolve:true ()) ];
    by_species =
      [
        ("squirtle", policy ~rules:[ rule "bite" "tail-whip" ] ~evolve:true ());
      ];
    default = policy ~evolve:true ();
  }

let turtle_moves =
  [ Some "tackle"; Some "tail-whip"; Some "withdraw"; Some "bubble" ]

let exp = Level_up.Exp None

let six_looks : Level_up.look list =
  [ exp; stats; stats ]
  @ [ exp; stats; Move_prompt; stats ]
  @ [ exp; stats; Move_prompt; stats ]
  @ [ exp; stats; Move_prompt ]
  @ [ exp; stats; stats; exp; stats; stats ]
  @ [ evolving; evolving; evolving; evolving; Move_prompt; evolving ]
  @ [ evolving; evolving; evolving; Back ]

let six_lists : Level_up.forget_list list =
  [
    { offered = Some "bite"; known = turtle_moves };
    offer "harden";
    { offered = Some "skull-bash"; known = turtle_moves };
  ]

let battle () =
  let g =
    {
      looks = six_looks;
      lists = six_lists;
      scenes =
        [ Ended; Continues; Ended; Continues; Ended; Ended; Ended; Ended ];
      trace = [];
    }
  in
  traced g
    (match Level_up.run (level_up_rig g) six_policies ~members:party with
    | Ok outcomes ->
        String.concat "; "
          (List.map
             (fun (o : Level_up.outcome) ->
               Printf.sprintf "%d: %s" o.member.slot (Level_up.describe o))
             outcomes)
    | Error why -> "failed: " ^ why)

let battles =
  [
    case "six members levelled by one battle, then their evolutions" battle
      "1: 2 levels; learned none; declined none; evolution evolved; 2: 2 \
       levels; learned none; declined an unread move; evolution cancelled; 3: \
       2 levels; learned bite; declined skull-bash; evolution evolved; 4: 1 \
       level; learned none; declined harden; evolution evolved; 5: 2 levels; \
       learned none; declined none; evolution evolved; 6: 2 levels; learned \
       none; declined none; evolution evolved [no, yes, forget 1, yes, leave, \
       wait, hold B, wait, wait, yes, leave, wait, wait, wait, wait]";
  ]

let () = Table_test.run "level up" (level_ups @ battles)
