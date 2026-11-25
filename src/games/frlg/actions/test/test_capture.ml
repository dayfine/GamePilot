(* The capture action: its args (pure), its decisions on fake game steps that
   answer each step from a list and records the steps, as the fork's
   test_capture_decisions (PokemonFRLG_AutoStoryCapture_Tests), and the line
   its encounters are read by. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

let decode json () =
  match Capture_plan.decode (obj json) with
  | Ok t ->
      Printf.sprintf "%s, pace %s" (Capture_plan.describe t)
        (Grid_geometry.Direction.name t.pace)
  | Error c -> Pokemon_checkpoints.Failure.cause_to_string c

let mg02_args =
  {|{"species": "spearow", "catches": 1, "encounters": 50, "balls": 10,
     "pace": "east"}|}

let decoding =
  [
    case "mg-02's catch_spearow" (decode mg02_args)
      "1 spearow, 50 encounters, 10 poke-ball, pace east";
    case "the fork's defaults"
      (decode {|{"species": "rattata"}|})
      "1 rattata, 20 encounters, 5 poke-ball, pace east";
    case "uncaught species with Ultra Balls"
      (decode
         {|{"uncaught": ["voltorb", "spearow", "ekans"], "catches": 2,
            "ball": "ultra-ball", "balls": 20, "pace": "west"}|})
      "2 uncaught species, 20 encounters, 20 ultra-ball, pace west";
    case "a species and uncaught"
      (decode {|{"species": "ekans", "uncaught": []}|})
      "bad_args: capture: species and uncaught: name one";
    case "a ball no Mart sells"
      (decode {|{"species": "ekans", "ball": "master-ball"}|})
      "bad_args: capture: ball is master-ball, not poke-ball, great-ball, \
       ultra-ball";
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

(* What the fake game answers: one encounter per battle (a species or none
   read, a "*" after it for the caught mark), one end per throw; finding an
   encounter fails once they run out. *)
type game = {
  mutable seen : Capture.encounter list;
  mutable throws : Capture.throw_end list;
  mutable trace : string list;
  flees : bool;
}

let note g s = g.trace <- s :: g.trace

let pop_seen g () : Capture.encounter =
  match g.seen with
  | [] -> { species = None; caught = false }
  | s :: rest ->
      g.seen <- rest;
      s

let seen_text (e : Capture.encounter) =
  Option.value e.species ~default:"?" ^ if e.caught then "*" else ""

let pop_throw g () : Capture.throw_end =
  match g.throws with
  | [] -> Throw_failed
  | t :: rest ->
      g.throws <- rest;
      t

let fake_game_steps g : Capture.game_steps =
  {
    find_encounter =
      (fun () ->
        let found = g.seen <> [] in
        note g (if found then "find" else "none");
        found);
    read_encounter =
      (fun () ->
        let s = pop_seen g () in
        note g ("see " ^ seen_text s);
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
          | Player_fainted -> "ball: player fainted"
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
    Capture_plan.target = Species "rattata";
    catches = 1;
    max_encounters = 20;
    max_balls = 5;
    ball = "poke-ball";
    pace = East;
  }

let new_species =
  {
    rattata with
    target = Uncaught [ "voltorb"; "spearow"; "ekans" ];
    catches = 2;
    ball = "ultra-ball";
  }

(* "rattata", None for unread; a trailing "*" for the caught mark. *)
let encounter = function
  | None -> { Capture.species = None; caught = false }
  | Some s when String.ends_with ~suffix:"*" s ->
      { species = Some (String.sub s 0 (String.length s - 1)); caught = true }
  | Some s -> { species = Some s; caught = false }

let decide ?(plan = rattata) ?(party = 2) ?(flees = true) seen throws () =
  let g = { seen = List.map encounter seen; throws; trace = []; flees } in
  let result = Capture.run (fake_game_steps g) plan ~party in
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
      "Capture of rattata: out of balls (the bag has no poke-ball): 1 \
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
    (* mGBA 2026-11-25, Victory Road: Machoke beat Mr. Mime after the ball;
       the capture ends with the battle on, as the fork's PLAYER_FAINTED. *)
    case "the player's Pokemon fainted after a throw ends it, no catch"
      (decide [ Some "rattata" ] [ Broke_free; Player_fainted ])
      "Capture of rattata: the player's Pokemon fainted: 1 encounters, 1 balls \
       thrown, 0 of 1 caught.: find, see rattata, ball: free, ball: player \
       fainted";
    case "a throw with no answer ends it"
      (decide [ Some "rattata" ] [ Throw_failed ])
      "Capture of rattata: the throw didn't end in a catch or at the battle \
       menu: 1 encounters, 0 balls thrown, 0 of 1 caught.: find, see rattata, \
       ball: ?";
    case "new species: a caught one is run from, an unread new one caught"
      (decide ~plan:new_species ~party:6
         [ Some "spearow*"; Some "voltorb"; Some "voltorb*"; None ]
         [ Broke_free; Caught; Caught ])
      "Capture: caught 2 uncaught species (voltorb to the PC, ? to the PC): 4 \
       encounters, 3 balls thrown, 2 of 2 caught.: find, see spearow*, run, \
       find, see voltorb, ball: free, ball: caught, to PC, find, see voltorb*, \
       run, find, see ?, ball: caught, to PC";
    case "new species: no Ultra Ball left"
      (decide ~plan:new_species [ Some "ekans" ] [ No_balls ])
      "Capture of uncaught species: out of balls (the bag has no ultra-ball): \
       1 encounters, 0 balls thrown, 0 of 2 caught.: find, see ekans, ball: \
       none, run";
    case "a caught mark on the named species does not stop its catch"
      (decide [ Some "rattata*" ] [ Caught ])
      "Capture: caught 1 rattata (party): 1 encounters, 1 balls thrown, 1 of 1 \
       caught.: find, see rattata*, ball: caught, to party";
  ]

let names =
  Frlg_text.Species_names.of_string
    "spearow SPEAROW\nnidoran-m NIDORAN\xe2\x99\x82\nmr-mime MR. MIME\n"

let opening species () = Capture_steps.opening_line names species

let reading =
  [
    case "the line a Spearow's battle opens with" (opening "spearow")
      "Wild SPEAROW appeared!";
    (* mGBA 2026-11-25, Route 3: "NIDORAN-M" never read. *)
    case "a Nidoran's: its sign, not the slug's -m" (opening "nidoran-m")
      "Wild NIDORAN\xe2\x99\x82 appeared!";
    case "a Mr. Mime's: its dot and space" (opening "mr-mime")
      "Wild MR. MIME appeared!";
    case "a slug not in the names: uppercased" (opening "pidgey")
      "Wild PIDGEY appeared!";
  ]

(* The looks a throw waits through, from the probes of real mGBA frames
   (fixtures/capture_throw.looks.jsonl, cut from the run's wire log): which show
   the player's Pokemon down. *)
let looks =
  List.map
    (fun (image, probes) -> (image, { Wire.seq = 0; t_ms = 0.; probes }))
    (Wire.read_image_probes "fixtures/capture_throw.looks.jsonl")

let player_down () =
  String.concat "; "
    (List.filter_map
       (fun (image, m) ->
         if Capture_steps.player_down m then
           Some (List.nth (String.split_on_char ',' image) 1 |> String.trim)
         else None)
       looks)

let throw_looks =
  [
    (* Not the catch's looks, nor a frame the player's bobbing box left. *)
    case "08-victory-road-rest testing-1: the player's Pokemon down" player_down
      "MR. MIME fainted (frame 445899); Use next POKEMON (frame 446100)";
  ]

let () = Table_test.run "capture" (decoding @ decisions @ reading @ throw_looks)
