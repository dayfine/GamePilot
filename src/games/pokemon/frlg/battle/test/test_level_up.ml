(* Level_up's decisions on fake game steps that answer each from a script
   and records the steps: one member's level-ups, who a screen is about, and
   six members levelled by one battle.

   [game] (Level_up_fake) is the fake console: given the scripted screens
   (looks), the lists to forget from and how each evolution scene leaves off,
   its [fake_game_steps] answer each call from that script and records the call
   ("yes", "no", "forget 1", "leave", "wait", "hold B"). [traced g text]
   appends the calls [g] saw, in order, in [...] after [text], so one string
   checks both the outcome and the exact presses. *)

open Frlg_battle
open Level_up_fake

let case name input expectation = { Table_test.name; input; expectation }

let settle ?(lists = []) looks policy () =
  let g = game ~lists looks in
  traced g
    (match
       Level_up.run (fake_game_steps g)
         (Level_up_policy.for_everyone policy)
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
    case "a move learned over a slot rule"
      (settle
         ~lists:[ offer "recycle" ]
         [ stats; Move_prompt; Back ]
         (policy ~rules:[ slot_rule "recycle" 2 ] ()))
      "1 level; learned recycle; declined none; evolution none [yes, forget 2]";
    case "nothing shows"
      (settle [ stats ] (policy ()))
      "failed: nothing to answer showed []";
  ]

(* Who a screen is about, when the game steps name the member: two members,
   the second's screens named out of slot order. *)
let pair ?(nicknames = (Some "CH'DING", Some "MIMIEN")) () :
    Level_up.member list =
  [
    { slot = 1; species = "gastly"; nickname = fst nicknames };
    { slot = 2; species = "mankey"; nickname = snd nicknames };
  ]

let named_run ?nicknames looks () =
  let g = game looks in
  let result =
    match
      Level_up.run (fake_game_steps g)
        (Level_up_policy.for_everyone (policy ()))
        ~members:(pair ?nicknames ())
    with
    | Ok outcomes ->
        String.concat "; "
          (List.map
             (fun (o : Level_up.outcome) ->
               Printf.sprintf "%d: %d" o.member.slot o.levels)
             outcomes)
    | Error why -> "failed: " ^ why
  in
  let by_order =
    List.filter
      (String.ends_with ~suffix:"going by the order.")
      (List.rev g.logs)
  in
  String.concat " " (result :: by_order)

let mimien = Some (Level_up.Nickname "MIMIEN")

let named =
  [
    case "a slot names the member"
      (named_run [ Exp (Some (Slot 2)); stats; Back ])
      "1: 0; 2: 1";
    case "a nickname names the member"
      (named_run [ Exp mimien; stats; Back ])
      "1: 0; 2: 1";
    case "a nickname not in the run fails"
      (named_run [ Exp (Some (Nickname "GASTLY")); stats; Back ])
      "failed: a screen names GASTLY, not in the run";
    case "a slot not in the run fails"
      (named_run [ Exp (Some (Slot 3)); stats; Back ])
      "failed: a screen names slot 3, not in the run";
    case "a nickname two members share: the order decides, and it is logged"
      (named_run
         ~nicknames:(Some "MIMIEN", Some "MIMIEN")
         [ Exp mimien; stats; Back ])
      "1: 1; 2: 0 Level up: MIMIEN names more than one member; going by the \
       order.";
  ]

(* A battle's shape: six members, each switched in once, so all gain EXP,
   all level (several levels each) and all evolve; names unread, so the run
   tracks them by order. Slot 2 cancels its evolution, the Squirtle learns
   Bite over Tail Whip, slot 4 has a rule that its move does not match and
   declines it; the rest decline at the prompt. *)
let party =
  List.mapi
    (fun i species : Level_up.member ->
      { slot = i + 1; species; nickname = None })
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

(* The battle, run once; each case below checks one part of it. *)
let battle =
  lazy
    (let g =
       game ~lists:six_lists
         ~scenes:
           [ Ended; Continues; Ended; Continues; Ended; Ended; Ended; Ended ]
         six_looks
     in
     let result =
       Level_up.run (fake_game_steps g) six_policies ~members:party
     in
     (result, traced g ""))

let member_outcome slot () =
  match fst (Lazy.force battle) with
  | Ok outcomes -> (
      match
        List.find_opt
          (fun (o : Level_up.outcome) -> o.member.slot = slot)
          outcomes
      with
      | Some o -> Level_up.describe o
      | None -> "no outcome")
  | Error why -> "failed: " ^ why

let member slot expectation =
  case
    (Printf.sprintf "the battle: slot %d" slot)
    (member_outcome slot) expectation

let battles =
  [
    member 1 "2 levels; learned none; declined none; evolution evolved";
    member 2
      "2 levels; learned none; declined an unread move; evolution cancelled";
    member 3 "2 levels; learned bite; declined skull-bash; evolution evolved";
    member 4 "1 level; learned none; declined harden; evolution evolved";
    member 5 "2 levels; learned none; declined none; evolution evolved";
    member 6 "2 levels; learned none; declined none; evolution evolved";
    case "the battle: the game steps taken, in order"
      (fun () -> String.trim (snd (Lazy.force battle)))
      "[no, yes, forget 1, yes, leave, wait, hold B, wait, wait, yes, leave, \
       wait, wait, wait, wait]";
  ]

let () = Table_test.run "level up" (level_ups @ named @ battles)
