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
let fake_candy_game_steps ~has_candy g : Rare_candy.game_steps =
  {
    open_candy =
      (fun ~slot ->
        note g (Printf.sprintf "open %d" slot);
        Ok (if has_candy then Rare_candy.Opened else No_candy));
    level_up = fake_game_steps g;
    close_bag = (fun () -> Ok (note g "close"));
    log = ignore;
  }

let candy ?(has_candy = true) looks () =
  let g = game looks in
  traced g
    (Rare_candy.describe
       (Rare_candy.run
          (fake_candy_game_steps ~has_candy g)
          (policy ()) ~member:gastly))

let candies =
  [
    case "a candy that took"
      (candy [ stats; Back ])
      "Rare Candy: 1 level; learned none; declined none; evolution none. [open \
       1, close]";
    case "a Lv 100 member: no effect" (candy [ Back ])
      "Rare Candy: 0 levels; learned none; declined none; evolution none. \
       [open 1, close]";
    case "out of candies"
      (candy ~has_candy:false [])
      "Rare Candy: none left in the bag. [open 1]";
    case "a level-up that failed: the bag left open" (candy [ stats ])
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

let fake_level_game_steps t : Candy_level.game_steps =
  {
    level =
      (fun ~slot:_ ->
        match t.levels with
        | [] -> Ok None
        | l :: rest ->
            t.levels <- rest;
            Ok l);
    candy =
      (fun ~slot:_ _ ->
        if t.candies = 0 then Out_of_candies
        else (
          t.candies <- t.candies - 1;
          t.used <- t.used + 1;
          Used
            {
              member = gastly;
              levels = 1;
              learned = [];
              declined = [];
              evolution = No_evolution;
            }));
    member =
      (fun ~slot ->
        Ok
          (Some
             {
               slot;
               species = t.species;
               level = Some 64;
               moves = Some t.moves;
             }));
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
  match Candy_level.run (fake_level_game_steps t) goal ~slot:1 with
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

let () = Table_test.run "rare candy" (decoding @ candies @ leveling)
