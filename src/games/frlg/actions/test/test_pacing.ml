(* The capture's search for a wild battle on a fake game that answers each
   step from a list, as the fork's PaceSim tests
   (PokemonFRLG_AutoStoryPaceSim_Tests): the ways stepped, and what the search
   found. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }

(* What follows a step: a battle's flash after its walk, a battle its turn
   started (the flash before the walk could end), a battle's wipe with its flash
   missed, a battle's screen with its flash missed, a trainer's message, or
   nothing. *)
type after = Flash | Turn_flash | Wipe | Missed | Trainer | Nothing

type game = {
  mutable afters : after list;
  mutable shown : after;
  spot : Pacing.spot ref;
  mutable trace : string list;
}

let note g s = g.trace <- s :: g.trace

let step g ~pace spot : Pacing.stepped =
  note g (Grid_geometry.Direction.name (Pacing.way ~pace spot));
  g.shown <-
    (match g.afters with
    | [] -> Nothing
    | a :: rest ->
        g.afters <- rest;
        a);
  match g.shown with
  | Flash -> Battle_on_walk
  | Turn_flash -> Battle_on_turn
  | Wipe -> Battle_unflashed
  | Missed | Trainer | Nothing -> Walked

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
  Pacing.pace_until_battle (steps g ~pace:East) ~pace:East g.spot ~max_steps

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

(* The same, with the way the player faces. *)
let stands_facing afters () =
  let g = new_game () in
  ignore (search g afters : bool);
  Printf.sprintf "%s facing %s"
    (Grid_geometry.Tile_pos.to_string
       (Pacing.stands_on ~pace:East !(g.spot) { x = 35; y = 6 }))
    (Option.fold ~none:"?" ~some:Grid_geometry.Direction.name !(g.spot).facing)

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
    (* mGBA 2026-11-25, Route 3: the flash 14 frames after the fourth step's
       turn tap; the game held the player on the tile east of the patch's,
       facing west. *)
    case "a battle the step's turn started: the tile before it, facing its way"
      (stands_facing [ Nothing; Nothing; Nothing; Turn_flash ])
      "(36, 6) facing west";
    case "the next search after a turn's battle steps without a turn"
      (fun () ->
        let g = new_game () in
        let first = search g [ Turn_flash ] in
        note g "|";
        let second = search g [ Flash ] in
        traced g (first && second))
      "true: east, |, east";
    (* mGBA 2026-11-25, Viridian Forest: the flash too faint to see, the next
       step saw the wipe. *)
    case "a missed flash, the wipe on the next step: that step stayed"
      (stands_facing [ Nothing; Wipe ])
      "(36, 6) facing east";
    case "a battle's screen after a step that saw nothing: that step stayed"
      (stands_facing [ Nothing; Missed ])
      "(36, 6) facing east";
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

(* A step's end from its watch: a turn and step's walk takes 607 ms. *)
let stepped sign () =
  match Pacing.stepped ~walk_ms:607. sign with
  | Walked -> "walked"
  | Battle_on_walk -> "battle on the walk"
  | Battle_on_turn -> "battle on the turn"
  | Battle_unflashed -> "battle, its flash missed"

let stepped_cases =
  [
    case "nothing seen" (stepped None) "walked";
    (* mGBA 2026-11-25, Route 3: 51 frames after the press. *)
    case "the flash after the walk"
      (stepped (Some (Flash_after 854.)))
      "battle on the walk";
    (* The same run: 24 frames after the press, the turn's flash. *)
    case "the flash before the walk could end"
      (stepped (Some (Flash_after 402.)))
      "battle on the turn";
    case "the wipe" (stepped (Some Going_black)) "battle, its flash missed";
  ]

let () = Table_test.run "pacing" (cases @ spot_cases @ stepped_cases)
