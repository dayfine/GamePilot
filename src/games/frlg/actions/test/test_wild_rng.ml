(* The wild_rng action: its args (pure), the blind presses for a target's
   timings (the fork's reset_and_perform_blind_sequence for Sweet Scent), and
   its decisions on fake game steps. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Json_field.as_object "" (Yojson.Safe.from_string json)

let plan_args =
  {|{"species": "ekans", "location": "route_10", "tid": 33002, "sid": 9011,
     "seeds": "rng_seeds_mgba_sevii_save.json", "seed_shift": 8,
     "frame_model": "mgba",
     "advances": [900, 4000], "ball": "poke-ball", "balls": 8}|}

let decode json () =
  match Wild_rng_plan.decode (obj json) with
  | Ok t ->
      Printf.sprintf
        "%s at %s, ids %d/%d, %s + %d (%s), advances %d..%d, in-game %d: %s"
        t.species t.location t.tid t.sid t.seeds t.seed_shift t.frame_model
        t.min_advance t.max_advance t.ingame_offset
        (Capture_plan.describe t.capture)
  | Error c -> Pokemon_engine.Failure.cause_to_string c

let decoding =
  [
    case "02-shiny-ekans's args" (decode plan_args)
      "ekans at route_10, ids 33002/9011, rng_seeds_mgba_sevii_save.json + 8 \
       (mgba), advances 900..4000, in-game 0: 1 ekans, 1 encounters, 8 \
       poke-ball";
    case "no seed_shift: 0"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "mgba"}|})
      "ekans at route_10, ids 1/2, x.json + 0 (mgba), advances 900..4000, \
       in-game 0: 1 ekans, 1 encounters, 5 poke-ball";
    case "an ingame_offset"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "ingame_offset": -1, "frame_model": "mgba"}|})
      "ekans at route_10, ids 1/2, x.json + 0 (mgba), advances 900..4000, \
       in-game -1: 1 ekans, 1 encounters, 5 poke-ball";
    case "an ingame_offset out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "ingame_offset": 100, "frame_model": "mgba"}|})
      "bad_args: wild_rng: ingame_offset is 100, not -99..99";
    case "a seed_shift out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "seed_shift": -4, "frame_model": "mgba"}|})
      "bad_args: wild_rng: seed_shift is -4, not 0..65535";
    case "a SID out of range"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 70000,
            "seeds": "x.json", "frame_model": "mgba"}|})
      "bad_args: wild_rng: sid is 70000, not 0..65535";
    case "an unknown frame model"
      (decode
         {|{"species": "ekans", "location": "route_10", "tid": 1, "sid": 2,
            "seeds": "x.json", "frame_model": "gba"}|})
      "bad_args: wild_rng: frame_model is gba, not mgba or switch";
  ]

(* The presses as "<button> <hold>/<release>" and "wait <ms>". *)
let command_text = function
  | Wire.Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms
  | Wire.Press { buttons; hold_ms; cooldown_ms; _ } ->
      Printf.sprintf "%s %d/%d"
        (String.concat "+" (List.map Wire.string_of_button buttons))
        hold_ms cooldown_ms

let blind () =
  Wild_rng_steps.blind_presses
    {
      seed_delay_ms = 33033;
      csf_delay_ms = 3348;
      teachy_delay_ms = 0;
      ingame_delay_ms = 10129;
    }
  |> List.map command_text |> String.concat ", "

let presses =
  [
    case "the seed 08F5 target's presses" blind
      "wait 33033, A 3000/0, wait 348, A 50/1450, B 50/2450, Start 200/300, \
       Down 200/300, A 200/1000, Up 200/300, Up 200/300, A 200/300, Down \
       200/2729, A 200/800";
  ]

let capture_result end_ : Capture.result =
  {
    end_;
    encounters = 1;
    balls_thrown = 1;
    caught =
      (if end_ = Capture.All_caught then
         [ { species = Some "ekans"; destination = Party } ]
       else []);
  }

(* The steps it took, and how it ended. *)
let decide ~capture_end ~shiny ~party () =
  let steps = ref [] in
  let game_steps : Wild_rng.game_steps =
    {
      catch =
        (fun _ ~party ->
          steps := Printf.sprintf "catch (party %d)" party :: !steps;
          capture_result capture_end);
      shiny_at =
        (fun slot ->
          steps := Printf.sprintf "summary %d" slot :: !steps;
          shiny);
      log = ignore;
    }
  in
  let plan =
    match Wild_rng_plan.decode (obj plan_args) with
    | Ok p -> p.capture
    | Error _ -> failwith "plan"
  in
  let r = Wild_rng.run game_steps plan ~party in
  String.concat ", " (List.rev !steps)
  ^ ": "
  ^ Option.value (Wild_rng.failure_code r.end_) ~default:"passes"

let decisions =
  [
    case "a shiny catch passes"
      (decide ~capture_end:All_caught ~shiny:true ~party:5)
      "catch (party 5), summary 6: passes";
    case "a catch without the star fails"
      (decide ~capture_end:All_caught ~shiny:false ~party:4)
      "catch (party 4), summary 5: wild_rng_not_shiny";
    case "another species: out of attempts, no summary"
      (decide ~capture_end:Out_of_encounters ~shiny:true ~party:5)
      "catch (party 5): wild_rng_out_of_encounters";
    case "a full party fails before the reset"
      (decide ~capture_end:All_caught ~shiny:true ~party:6)
      ": wild_rng_party_full";
  ]

let () = Table_test.run "wild_rng" (decoding @ presses @ decisions)
