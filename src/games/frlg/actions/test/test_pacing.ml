(* The capture's search for a wild battle on a fake game that answers each
   step from a list, as the fork's PaceSim tests
   (PokemonFRLG_AutoStoryPaceSim_Tests): the ways stepped, and what the search
   found. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }

(* What follows a step: a battle's flash, a battle whose flash was missed, a
   trainer's message, or nothing. *)
type after = Flash | Missed | Trainer | Nothing

type game = {
  mutable afters : after list;
  mutable shown : after;
  spot : Pacing.spot ref;
  mutable trace : string list;
}

let note g s = g.trace <- s :: g.trace

let step g ~pace () =
  note g (Grid_geometry.Direction.name (Pacing.way ~pace !(g.spot)));
  g.spot := Pacing.after_step ~pace !(g.spot);
  g.shown <-
    (match g.afters with
    | [] -> Nothing
    | a :: rest ->
        g.afters <- rest;
        a);
  g.shown = Flash

let steps g ~pace : Pacing.steps =
  {
    step = step g ~pace;
    battle_shows = (fun () -> g.shown = Missed);
    overworld_shows = (fun () -> g.shown = Nothing);
    message_shows = (fun () -> g.shown = Trainer);
    fight_trainer =
      (fun () ->
        note g "fight";
        g.shown <- Nothing;
        g.spot := Pacing.on_patch None;
        "a trainer");
    log = ignore;
  }

let new_game () =
  {
    afters = [];
    shown = Nothing;
    spot = ref (Pacing.on_patch (Some East));
    trace = [];
  }

let search g ?(max_steps = 10) afters =
  g.afters <- afters;
  Pacing.pace_until_battle (steps g ~pace:East) ~max_steps

let traced g found =
  Printf.sprintf "%b: %s" found (String.concat ", " (List.rev g.trace))

let one ?max_steps afters () =
  let g = new_game () in
  traced g (search g ?max_steps afters)

(* mg-02 testing runs 8 and 12: turning in place drifted the player off the
   grass. The next search starts from the tile the last battle left them on. *)
let two_searches () =
  let g = new_game () in
  let first = search g [ Nothing; Nothing; Flash ] in
  note g "|";
  let second = search g [ Flash ] in
  traced g (first && second)

(* Where the capture leaves the player for the plan's next event. *)
let stands_after afters () =
  let g = new_game () in
  ignore (search g afters : bool);
  Grid_geometry.Tile_pos.to_string
    (Pacing.stands_on ~pace:East !(g.spot) { x = 35; y = 6 })

let cases =
  [
    case "a battle on the step out: a tile east of the patch's tile"
      (stands_after [ Flash ]) "(36, 6)";
    case "a battle on the step back: on the patch's tile"
      (stands_after [ Nothing; Flash ])
      "(35, 6)";
    case "pace and back until the flash"
      (one [ Nothing; Nothing; Flash ])
      "true: east, west, east";
    case "the next search steps back first" two_searches
      "true: east, west, east, |, west";
    case "a missed flash, found by the battle's screen"
      (one [ Nothing; Missed ])
      "true: east, west";
    case "a trainer is fought, then pacing goes on from the patch's tile"
      (one [ Nothing; Trainer; Flash ])
      "true: east, west, fight, east";
    case "no battle in the steps" (one ~max_steps:3 [])
      "false: east, west, east";
  ]

(* mg-05a testing 1: the PP drain turned in place on Route 8 (45, 12) and ended
   on the path at (46, 12), where no battle comes. A tile off the patch is no
   spot to pace from. *)
let spot_at tile () =
  let tile = { Grid_geometry.Tile_pos.x = fst tile; y = snd tile } in
  match
    Pacing.spot_at ~pace:West ~patch:{ x = 45; y = 12 } tile (Some East)
  with
  | None -> "off the patch"
  | Some { displaced; facing } ->
      Printf.sprintf "displaced %b, facing %s" displaced
        (Option.fold ~none:"?" ~some:Grid_geometry.Direction.name facing)

let spot_cases =
  [
    case "on the patch" (spot_at (45, 12)) "displaced false, facing east";
    case "one tile the pace's way"
      (spot_at (44, 12))
      "displaced true, facing east";
    case "the path the turning drifted onto" (spot_at (46, 12)) "off the patch";
  ]

let () = Table_test.run "pacing" (cases @ spot_cases)
