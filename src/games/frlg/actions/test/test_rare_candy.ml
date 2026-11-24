(* The Rare Candy actions: their args (pure), the level-up decisions and one candy on a fake
   rig that answers each step from a script and records the steps, and the
   leveling loop on a fake that counts candies. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Grid_maps.Json_field.as_object "" (Yojson.Safe.from_string json)
let cause = Story.Failure.cause_to_string

let decode_use json () =
  match Candy_plan.decode_use (obj json) with
  | Ok u -> Candy_plan.describe_use u
  | Error c -> cause c

let decode_goal json () =
  match Candy_plan.decode_goal (obj json) with
  | Ok g -> Candy_plan.describe_goal g
  | Error c -> cause c

let haunter_goal =
  {|{"species": "gastly", "target_level": 64, "evolve": true,
     "learn": [{"move": "mean-look", "replacing": "lick"}],
     "expect_species": "haunter", "expect_moves": ["hypnosis", "mean-look"]}|}

let decoding =
  [
    case "a slot, declining every move"
      (decode_use {|{"target_slot": 1, "evolve": false}|})
      "slot 1, learn nothing offered, no evolution";
    case "a species with a rule"
      (decode_use
         {|{"species": "paras", "evolve": true,
            "learn": [{"move": "spore", "replacing": "scratch"}]}|})
      "paras, learn spore over scratch, evolve";
    case "evolve left out"
      (decode_use {|{"target_slot": 1}|})
      "bad_args: use_rare_candy: evolve is missing";
    case "a rule over itself"
      (decode_use
         {|{"target_slot": 1, "evolve": false,
            "learn": [{"move": "spore", "replacing": "spore"}]}|})
      "bad_args: use_rare_candy: learn[0].replacing is the move itself, spore";
    case "the Haunter goal" (decode_goal haunter_goal)
      "gastly, learn mean-look over lick, evolve to Lv 64 (at most 99 \
       candies), then a haunter, knowing hypnosis, mean-look";
    case "a target past 100"
      (decode_goal {|{"target_slot": 1, "evolve": false, "target_level": 101}|})
      "bad_args: candy_level: target_level is 101, not 2..100";
  ]

(* The fake game: the looks [next] answers in order, the list each opened
   list shows in order, whether the candy is there. Its level-up rig serves
   any context; [Back] is wherever the context ends. *)
type game = {
  mutable looks : Level_up.look list;
  mutable lists : Level_up.forget_list list;
  has_candy : bool;
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
    evolution = (fun ~cancel -> note g (if cancel then "hold B" else "wait"));
    log = ignore;
  }

let candy_rig g : Rare_candy.rig =
  {
    open_candy =
      (fun ~slot ->
        note g (Printf.sprintf "open %d" slot);
        if g.has_candy then Opened else No_candy);
    level_up = level_up_rig g;
    close_bag = (fun () -> note g "close");
    log = ignore;
  }

let known = [ Some "lick"; Some "hypnosis"; Some "spite"; Some "curse" ]
let offer move : Level_up.forget_list = { offered = Some move; known }
let rule learn replacing : Level_up.move_rule = { learn; replacing }

let policy ?(rules = []) ?(evolve = false) () : Level_up.policy =
  { rules; evolve }

let traced g text = text ^ " [" ^ String.concat ", " (List.rev g.trace) ^ "]"

let settle ?(lists = []) looks policy () =
  let g = { looks; lists; has_candy = true; trace = [] } in
  traced g
    (match Level_up.run (level_up_rig g) policy with
    | Ok o -> Level_up.describe o
    | Error why -> "failed: " ^ why)

let mean_look = [ rule "mean-look" "lick" ]

let level_ups =
  [
    case "a level, nothing more"
      (settle [ Stats; Back ] (policy ()))
      "1 level; learned none; declined none; evolution none []";
    case "a move learned over the rule's move"
      (settle
         ~lists:[ offer "mean-look" ]
         [ Stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined none; evolution none [yes, forget \
       0]";
    case "no rules: declined at the prompt"
      (settle [ Stats; Move_prompt; Back ] (policy ()))
      "1 level; learned none; declined an unread move; evolution none [no]";
    case "a move no rule names: the list left"
      (settle
         ~lists:[ offer "night-shade" ]
         [ Stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned none; declined night-shade; evolution none [yes, leave]";
    case "two moves at one level: one learned, one declined"
      (settle
         ~lists:[ offer "night-shade"; offer "mean-look" ]
         [ Stats; Move_prompt; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined night-shade; evolution none [yes, \
       leave, yes, forget 0]";
    case "two levels in a row, each with its prompt (a battle's shape)"
      (settle
         ~lists:[ offer "night-shade"; offer "mean-look" ]
         [ Stats; Move_prompt; Stats; Move_prompt; Evolving; Back ]
         (policy ~rules:mean_look ~evolve:true ()))
      "2 levels; learned mean-look; declined night-shade; evolution evolved \
       [yes, leave, yes, forget 0, wait]";
    case "the rule's move to replace not known: declined"
      (settle
         ~lists:[ offer "spore" ]
         [ Stats; Move_prompt; Back ]
         (policy ~rules:[ rule "spore" "scratch" ] ()))
      "1 level; learned none; declined spore; evolution none [yes, leave]";
    case "the offered move unread: the list left"
      (settle
         ~lists:[ { offered = None; known } ]
         [ Stats; Move_prompt; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned none; declined an unread move; evolution none [yes, \
       leave]";
    case "a list opened by a stray A"
      (settle
         ~lists:[ offer "mean-look" ]
         [ Stats; Forget_list; Back ]
         (policy ~rules:mean_look ()))
      "1 level; learned mean-look; declined none; evolution none [forget 0]";
    case "an evolution let run, then its move asked"
      (settle
         ~lists:[ offer "mean-look" ]
         [ Stats; Evolving; Move_prompt; Evolving; Back ]
         (policy ~rules:mean_look ~evolve:true ()))
      "1 level; learned mean-look; declined none; evolution evolved [wait, \
       yes, forget 0, wait]";
    case "an evolution cancelled once, then waited out"
      (settle [ Stats; Evolving; Evolving; Back ] (policy ()))
      "1 level; learned none; declined none; evolution cancelled [hold B, wait]";
    case "nothing shows"
      (settle [ Stats ] (policy ()))
      "failed: nothing to answer showed []";
  ]

let candy ?(has_candy = true) looks () =
  let g = { looks; lists = []; has_candy; trace = [] } in
  traced g
    (Rare_candy.describe (Rare_candy.run (candy_rig g) (policy ()) ~slot:1))

let candies =
  [
    case "a candy that took"
      (candy [ Stats; Back ])
      "Rare Candy: 1 level; learned none; declined none; evolution none. [open \
       1, close]";
    case "a Lv 100 member: no effect" (candy [ Back ])
      "Rare Candy: 0 levels; learned none; declined none; evolution none. \
       [open 1, close]";
    case "out of candies"
      (candy ~has_candy:false [])
      "Rare Candy: none left in the bag. [open 1]";
    case "a level-up that failed: the bag left open" (candy [ Stats ])
      "Rare Candy: failed: nothing to answer showed. [open 1]";
  ]

(* The leveling loop's fake: levels read in order ([None]: unread), candies
   in the bag, and the summary at the end. *)
type trainer = {
  mutable levels : int option list;
  mutable candies : int;
  mutable used : int;
  species : string;
  moves : string list;
}

let level_rig t : Candy_level.rig =
  {
    level =
      (fun ~slot:_ ->
        match t.levels with
        | [] -> None
        | l :: rest ->
            t.levels <- rest;
            l);
    candy =
      (fun ~slot:_ _ ->
        if t.candies = 0 then Out_of_candies
        else (
          t.candies <- t.candies - 1;
          t.used <- t.used + 1;
          Used
            {
              levels = 1;
              learned = [];
              declined = [];
              evolution = No_evolution;
            }));
    member =
      (fun ~slot ->
        Some
          { slot; species = t.species; level = Some 64; moves = Some t.moves });
    log = ignore;
  }

let goal ?(species = None) ?(moves = []) target : Candy_plan.goal =
  {
    use = { member = Slot 1; policy = policy () };
    target_level = target;
    species;
    moves;
    max_candies = Candy_plan.default_max_candies;
  }

let train ?(candies = 10) ?(species = "haunter") ?(moves = [ "hypnosis" ])
    levels goal () =
  let t = { levels; candies; used = 0; species; moves } in
  match Candy_level.run (level_rig t) goal ~slot:1 with
  | Ok r ->
      Printf.sprintf "Lv %d %s after %d candies" r.level r.species r.candies
  | Error c -> cause c ^ Printf.sprintf " (%d used)" t.used

let some = List.map Option.some

let leveling =
  [
    case "to the target"
      (train (some [ 61; 62; 63; 64 ]) (goal 64))
      "Lv 64 haunter after 3 candies";
    case "at the target already: no candy"
      (train (some [ 64 ]) (goal 64))
      "Lv 64 haunter after 0 candies";
    case "out of candies short of it"
      (train ~candies:1 (some [ 62; 63 ]) (goal 64))
      "out_of_candies: no Rare Candy left: slot 1 is Lv 63, not 64 (1 used)";
    case "a level not read"
      (train [ Some 62; None ] (goal 64))
      "level_unread: slot 1's level did not read (1 used)";
    case "a candy that did not raise the level"
      (train (some [ 62; 62 ]) (goal 64))
      "level_stuck: slot 1 still reads Lv 62 after a candy (1 used)";
    case "the species expected"
      (train (some [ 64 ]) (goal ~species:(Some "gastly") 64))
      "species_wrong: slot 1 is a haunter, not a gastly (0 used)";
    case "a move missing"
      (train (some [ 64 ]) (goal ~moves:[ "hypnosis"; "mean-look" ] 64))
      "moves_missing: slot 1 knows hypnosis, not mean-look (0 used)";
  ]

let () = Table_test.run "rare candy" (decoding @ level_ups @ candies @ leveling)
