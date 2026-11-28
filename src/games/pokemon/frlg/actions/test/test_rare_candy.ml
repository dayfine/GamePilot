(* The Rare Candy actions: their args (pure), one candy on Level_up's fake game steps
   (test_level_up has the level-up decisions), and the leveling loop on a fake
   that counts candies. *)

open Frlg_actions
open Frlg_level_up_fake
open Level_up_fake

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)
let cause = Pokemon_engine.Failure.cause_to_string

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

(* The candy on Level_up's fake game steps, with or without a candy in the bag. *)
let fake_candy_game_steps ?(has_bag_candy = true) ?(has_use_candy = true) g :
    Rare_candy.game_steps =
  {
    open_bag =
      (fun () ->
        note g "open_bag";
        Ok (if has_bag_candy then Rare_candy.Opened else No_candy));
    use_candy =
      (fun ~slot ->
        note g (Printf.sprintf "use %d" slot);
        Ok (if has_use_candy then Rare_candy.Opened else No_candy));
    level_up = fake_game_steps g;
    close_bag = (fun () -> Ok (note g "close_bag"));
    log = ignore;
  }

let candy ?(has_bag_candy = true) ?(has_use_candy = true) looks () =
  let g = game looks in
  traced g
    (Rare_candy.describe
       (Rare_candy.run
          (fake_candy_game_steps ~has_bag_candy ~has_use_candy g)
          (policy ()) ~member:gastly))

let candy_in_bag looks () =
  let g = game looks in
  traced g
    (Rare_candy.describe
       (Rare_candy.use_one (fake_candy_game_steps g) (policy ()) ~member:gastly))

let candies =
  [
    case "a candy that took"
      (candy [ stats; Back ])
      "Rare Candy: 1 level; learned none; declined none; evolution none. \
       [open_bag, use 1, close_bag]";
    case "a Lv 100 member: no effect" (candy [ Back ])
      "Rare Candy: 0 levels; learned none; declined none; evolution none. \
       [open_bag, use 1, close_bag]";
    case "out of candies when opening bag"
      (candy ~has_bag_candy:false [])
      "Rare Candy: none left in the bag. [open_bag]";
    case "out of candies when using from open bag"
      (candy ~has_use_candy:false [])
      "Rare Candy: none left in the bag. [open_bag, use 1, close_bag]";
    case "a level-up that failed: the bag left open" (candy [ stats ])
      "Rare Candy: failed: nothing to answer showed. [open_bag, use 1]";
    case "use_one stays inside the open bag"
      (candy_in_bag [ stats; Back ])
      "Rare Candy: 1 level; learned none; declined none; evolution none. [use \
       1]";
  ]

(* The leveling loop's fake: starting level, scripted per-candy outcomes, counts
   of bag opens/closes and summary reads, and the final summary. *)
type trainer = {
  start_level : int option;
  has_bag_candy : bool;
  mutable outcomes : Rare_candy.result list;
  mutable level_reads : int;
  mutable bag_opens : int;
  mutable bag_closes : int;
  mutable used : int;
  mutable member_reads : int;
  final_level : int option;
  species : string;
  moves : string list;
}

let one_level_outcome =
  Rare_candy.Used
    {
      member = gastly;
      levels = 1;
      learned = [];
      declined = [];
      evolution = No_evolution;
    }

let fake_level_game_steps t : Candy_level.game_steps =
  {
    read_level =
      (fun ~slot:_ ->
        t.level_reads <- t.level_reads + 1;
        Ok t.start_level);
    open_bag =
      (fun () ->
        t.bag_opens <- t.bag_opens + 1;
        Ok (if t.has_bag_candy then Rare_candy.Opened else No_candy));
    use_candy =
      (fun ~slot:_ _ ->
        match t.outcomes with
        | [] -> Out_of_candies
        | res :: rest ->
            t.outcomes <- rest;
            (match res with
            | Used o when o.levels > 0 -> t.used <- t.used + 1
            | _ -> ());
            res);
    close_bag =
      (fun () ->
        t.bag_closes <- t.bag_closes + 1;
        Ok ());
    read_member =
      (fun ~slot ->
        t.member_reads <- t.member_reads + 1;
        Ok
          (Some
             {
               slot;
               species = t.species;
               level = t.final_level;
               moves = Some t.moves;
             }));
    log = ignore;
  }

let goal ?(species = None) ?(moves = [])
    ?(max_candies = Candy_plan.default_max_candies) target : Candy_plan.goal =
  {
    use = { member = Slot 1; policy = policy () };
    target_level = target;
    species;
    moves;
    max_candies;
  }

let counts t =
  Printf.sprintf "reads=%d/%d bag=%d/%d" t.level_reads t.member_reads
    t.bag_opens t.bag_closes

let train ?(has_bag_candy = true) ?outcomes ?(candies = 10) ?final_level
    ?(species = "haunter") ?(moves = [ "hypnosis" ]) start_level goal () =
  let outcomes =
    match outcomes with
    | Some xs -> xs
    | None -> List.init candies (fun _ -> one_level_outcome)
  in
  let final_level =
    match final_level with
    | Some l -> l
    | None -> Some goal.Candy_plan.target_level
  in
  let t =
    {
      start_level;
      has_bag_candy;
      outcomes;
      level_reads = 0;
      bag_opens = 0;
      bag_closes = 0;
      used = 0;
      member_reads = 0;
      final_level;
      species;
      moves;
    }
  in
  match Candy_level.run (fake_level_game_steps t) goal ~slot:1 with
  | Ok r ->
      Printf.sprintf "Lv %d %s after %d candies (%s)" r.level r.species
        r.candies (counts t)
  | Error c -> Printf.sprintf "%s (%d used, %s)" (cause c) t.used (counts t)

let train_events () =
  let learn_rule : Frlg_battle.Level_up_policy.move_rule =
    { learn = "mean-look"; replacing = Named "lick" }
  in
  let outcomes : Rare_candy.result list =
    [
      Used
        {
          member = gastly;
          levels = 1;
          learned = [ learn_rule ];
          declined = [];
          evolution = No_evolution;
        };
      Used
        {
          member = gastly;
          levels = 1;
          learned = [];
          declined = [];
          evolution = Evolved;
        };
      Used
        {
          member = gastly;
          levels = 1;
          learned = [];
          declined = [ Some "curse" ];
          evolution = No_evolution;
        };
    ]
  in
  let t =
    {
      start_level = Some 24;
      has_bag_candy = true;
      outcomes;
      level_reads = 0;
      bag_opens = 0;
      bag_closes = 0;
      used = 0;
      member_reads = 0;
      final_level = Some 27;
      species = "haunter";
      moves = [ "hypnosis"; "mean-look" ];
    }
  in
  match Candy_level.run (fake_level_game_steps t) (goal 27) ~slot:1 with
  | Error c -> cause c
  | Ok r ->
      Printf.sprintf "candies=%d learned=%d declined=%d evos=%d %s" r.candies
        (List.length r.learned) (List.length r.declined)
        (List.length r.evolutions) (counts t)

let no_effect_outcome =
  Rare_candy.Used
    {
      member = gastly;
      levels = 0;
      learned = [];
      declined = [];
      evolution = No_evolution;
    }

let leveling =
  [
    case "multi-candy batch opens and closes bag once"
      (train (Some 61) (goal 64))
      "Lv 64 haunter after 3 candies (reads=1/1 bag=1/1)";
    case "at the target already: bag never opened"
      (train (Some 64) (goal 64))
      "Lv 64 haunter after 0 candies (reads=1/1 bag=0/0)";
    case "move-learn and evolution mid-batch" train_events
      "candies=3 learned=1 declined=1 evos=1 reads=1/1 bag=1/1";
    case "out of candies when opening bag"
      (train ~has_bag_candy:false (Some 62) (goal 64))
      "out_of_candies: no Rare Candy left: slot 1 is Lv 62, not 64 (0 used, \
       reads=1/0 bag=1/0)";
    case "out of candies mid-batch closes bag"
      (train ~candies:1 (Some 62) (goal 64))
      "out_of_candies: no Rare Candy left: slot 1 is Lv 63, not 64 (1 used, \
       reads=1/0 bag=1/1)";
    case "no effect mid-batch closes bag"
      (train
         ~outcomes:[ one_level_outcome; no_effect_outcome ]
         (Some 62) (goal 64))
      "no_effect: the candy did not take on slot 1 (Lv 63) (1 used, reads=1/0 \
       bag=1/1)";
    case "level-up failure leaves bag open"
      (train
         ~outcomes:[ one_level_outcome; Failed "nothing to answer showed" ]
         (Some 62) (goal 64))
      "rare_candy_failed: nothing to answer showed (1 used, reads=1/0 bag=1/0)";
    case "max_candies stops batch and closes bag"
      (train (Some 60) (goal ~max_candies:2 64))
      "max_candies: 2 candies used and slot 1 is Lv 62, not 64 (2 used, \
       reads=1/0 bag=1/1)";
    case "starting level not read"
      (train None (goal 64))
      "level_unread: slot 1's level did not read (0 used, reads=1/0 bag=0/0)";
    case "final summary short of target"
      (train ~final_level:(Some 63) (Some 61) (goal 64))
      "level_short: the summary reads Lv 63, not 64 (3 used, reads=1/1 bag=1/1)";
    case "the species expected"
      (train (Some 64) (goal ~species:(Some "gastly") 64))
      "species_wrong: slot 1 is a haunter, not a gastly (0 used, reads=1/1 \
       bag=0/0)";
    case "a move missing"
      (train (Some 64) (goal ~moves:[ "hypnosis"; "mean-look" ] 64))
      "moves_missing: slot 1 knows hypnosis, not mean-look (0 used, reads=1/1 \
       bag=0/0)";
  ]

let () = Table_test.run "rare candy" (decoding @ candies @ leveling)
