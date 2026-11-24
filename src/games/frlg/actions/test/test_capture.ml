(* The capture action: its args (pure), its decisions on a fake rig that
   answers each step from a list and records the steps, as the fork's
   test_capture_decisions (PokemonFRLG_AutoStoryCapture_Tests), and the line
   its encounters are read by. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Grid_maps.Json_field.as_object "" (Yojson.Safe.from_string json)

let decode json () =
  match Capture_plan.decode (obj json) with
  | Ok t ->
      Printf.sprintf "%s, pace %s" (Capture_plan.describe t)
        (Grid_maps.Direction.name t.pace)
  | Error c -> Story.Failure.cause_to_string c

let mg02_args =
  {|{"species": "spearow", "catches": 1, "encounters": 50, "balls": 10,
     "pace": "east"}|}

let decoding =
  [
    case "mg-02's catch_spearow" (decode mg02_args)
      "1 spearow, 50 encounters, 10 balls, pace east";
    case "the fork's defaults"
      (decode {|{"species": "rattata"}|})
      "1 rattata, 20 encounters, 5 balls, pace east";
    case "no species"
      (decode {|{"catches": 2}|})
      "bad_args: capture: species is missing.";
    case "no catch asked for"
      (decode {|{"species": "rattata", "catches": 0}|})
      "bad_args: capture: catches is 0, not 1..999";
    case "a weakening move, not ported"
      (decode {|{"species": "rattata", "move": 1}|})
      "bad_args: capture: move: the weakening move is not ported";
  ]

(* What the fake game answers: one species (or none read) per encounter, one
   end per throw; finding an encounter fails once they run out. *)
type game = {
  mutable seen : string option list;
  mutable throws : Capture.throw_end list;
  mutable trace : string list;
  flees : bool;
}

let note g s = g.trace <- s :: g.trace

let pop_seen g () =
  match g.seen with
  | [] -> None
  | s :: rest ->
      g.seen <- rest;
      s

let pop_throw g () : Capture.throw_end =
  match g.throws with
  | [] -> Throw_failed
  | t :: rest ->
      g.throws <- rest;
      t

let rig g : Capture.rig =
  {
    find_encounter =
      (fun () ->
        let found = g.seen <> [] in
        note g (if found then "find" else "none");
        found);
    read_encounter =
      (fun () ->
        let s = pop_seen g () in
        note g ("see " ^ Option.value s ~default:"?");
        s);
    flee =
      (fun () ->
        note g "run";
        g.flees);
    throw_ball =
      (fun () ->
        let t = pop_throw g () in
        note g
          (match t with
          | Caught -> "ball: caught"
          | Broke_free -> "ball: free"
          | No_balls -> "ball: none"
          | Throw_failed -> "ball: ?");
        t);
    finish_catch =
      (fun d ->
        note g (match d with Party -> "to party" | Pc -> "to PC");
        true);
    log = ignore;
  }

let rattata =
  {
    Capture_plan.species = "rattata";
    catches = 1;
    max_encounters = 20;
    max_balls = 5;
    pace = East;
  }

let decide ?(plan = rattata) ?(party = 2) ?(flees = true) seen throws () =
  let g = { seen; throws; trace = []; flees } in
  let result = Capture.run (rig g) plan ~party in
  Printf.sprintf "%s: %s"
    (Capture.message plan result)
    (String.concat ", " (List.rev g.trace))

let decisions =
  [
    case "caught with the first ball"
      (decide [ Some "rattata" ] [ Caught ])
      "Capture: caught 1 rattata (party): 1 encounters, 1 balls thrown, 1 of 1 \
       caught.: find, see rattata, ball: caught, to party";
    case "another species and an unread one are run from"
      (decide [ Some "pidgey"; None; Some "rattata" ] [ Caught ])
      "Capture: caught 1 rattata (party): 3 encounters, 1 balls thrown, 1 of 1 \
       caught.: find, see pidgey, run, find, see ?, run, find, see rattata, \
       ball: caught, to party";
    case "it broke free, then the next ball"
      (decide [ Some "rattata" ] [ Broke_free; Caught ])
      "Capture: caught 1 rattata (party): 1 encounters, 2 balls thrown, 1 of 1 \
       caught.: find, see rattata, ball: free, ball: caught, to party";
    case "a full party sends it to the PC"
      (decide ~party:6 [ Some "rattata" ] [ Caught ])
      "Capture: caught 1 rattata (PC): 1 encounters, 1 balls thrown, 1 of 1 \
       caught.: find, see rattata, ball: caught, to PC";
    case "the ball cap reached in its battle: run"
      (decide
         ~plan:{ rattata with max_balls = 2 }
         [ Some "rattata" ] [ Broke_free; Broke_free ])
      "Capture of rattata: out of balls: 1 encounters, 2 balls thrown, 0 of 1 \
       caught.: find, see rattata, ball: free, ball: free, run";
    case "the bag has no Poke Ball: run"
      (decide [ Some "rattata" ] [ No_balls ])
      "Capture of rattata: out of balls (the bag has no Poke Ball): 1 \
       encounters, 0 balls thrown, 0 of 1 caught.: find, see rattata, ball: \
       none, run";
    case "the encounter cap"
      (decide
         ~plan:{ rattata with max_encounters = 2 }
         [ Some "pidgey"; Some "pidgey"; Some "rattata" ]
         [])
      "Capture of rattata: out of encounters: 2 encounters, 0 balls thrown, 0 \
       of 1 caught.: find, see pidgey, run, find, see pidgey, run";
    case "no wild battle" (decide [] [])
      "Capture of rattata: no wild battle started: 0 encounters, 0 balls \
       thrown, 0 of 1 caught.: none";
    case "a run that fails ends it"
      (decide ~flees:false [ Some "pidgey" ] [])
      "Capture of rattata: couldn't run from pidgey: 1 encounters, 0 balls \
       thrown, 0 of 1 caught.: find, see pidgey, run";
    case "a throw with no answer ends it"
      (decide [ Some "rattata" ] [ Throw_failed ])
      "Capture of rattata: the throw didn't end in a catch or at the battle \
       menu: 1 encounters, 0 balls thrown, 0 of 1 caught.: find, see rattata, \
       ball: ?";
  ]

let reading =
  [
    case "the line a Spearow's battle opens with"
      (fun () -> Capture_steps.opening_line "spearow")
      "Wild SPEAROW appeared!";
  ]

let () = Table_test.run "capture" (decoding @ decisions @ reading)
