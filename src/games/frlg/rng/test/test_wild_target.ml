(* Wild_target, Seeds_database.of_json and Encounters_database on the mGBA
   run that caught a shiny Ekans on Route 10 (TID 33002, SID 9011): seed BEF4,
   pressed 1837 frames (30756 ms) after the reset (the lab's 1836, counted
   from a frame after it), advance 1555. The seed table is the asset measured
   on mGBA from the Sevii save; the Route 10 save that run booted from adds 8
   to each of its seeds (the plan's seed_offset). *)

open Frlg_rng

let route10 =
  {|{"grass": {"route_10": [
  {"species": "spearow", "minLevel": 16, "maxLevel": 16},
  {"species": "voltorb", "minLevel": 16, "maxLevel": 16},
  {"species": "ekans", "minLevel": 11, "maxLevel": 11},
  {"species": "ekans", "minLevel": 15, "maxLevel": 15},
  {"species": "spearow", "minLevel": 13, "maxLevel": 13},
  {"species": "voltorb", "minLevel": 14, "maxLevel": 14},
  {"species": "spearow", "minLevel": 17, "maxLevel": 17},
  {"species": "voltorb", "minLevel": 17, "maxLevel": 17},
  {"species": "voltorb", "minLevel": 14, "maxLevel": 14},
  {"species": "ekans", "minLevel": 13, "maxLevel": 13},
  {"species": "voltorb", "minLevel": 14, "maxLevel": 14},
  {"species": "ekans", "minLevel": 17, "maxLevel": 17}]}}|}

let slots () =
  match Encounters_database.of_json (Yojson.Safe.from_string route10) with
  | Error e -> failwith e
  | Ok db -> (
      match Encounters_database.slots db ~kind:"grass" ~location:"route_10" with
      | Some s -> s
      | None -> failwith "no route_10")

let tid_xor_sid = 33002 lxor 9011

let found = function
  | None -> "none"
  | Some (t : Wild_target.t) ->
      Printf.sprintf "%s; csf %d ingame %d" (Wild_target.describe t)
        t.timings.csf_delay_ms t.timings.ingame_delay_ms

let one_row () =
  Wild_target.find Rng_timings.mgba ~delays:[| 30756 |] ~seeds:[| 0xBEF4 |]
    (slots ()) ~species:"ekans" ~tid_xor_sid ~min_advance:1300 ~max_advance:1600
  |> found

let sevii_table = "../../assets/rng_seeds_mgba_sevii_save.json"
let route10_save_offset = 8

let table () =
  match Seeds_database.of_json (Yojson.Safe.from_file sevii_table) with
  | Error e -> "error: " ^ e
  | Ok db ->
      let c = List.hd db.columns in
      Printf.sprintf "%s, %d rows, %d ms: %04X, %d ms: %04X" c.name
        (Array.length db.delays) db.delays.(103) c.seeds.(103) db.delays.(0)
        c.seeds.(0)

let soonest () =
  match Seeds_database.of_json (Yojson.Safe.from_file sevii_table) with
  | Error e -> "error: " ^ e
  | Ok db ->
      let c = List.hd db.columns in
      let seeds =
        Array.map (fun s -> (s + route10_save_offset) land 0xffff) c.seeds
      in
      Wild_target.find Rng_timings.mgba ~delays:db.delays ~seeds (slots ())
        ~species:"ekans" ~tid_xor_sid ~min_advance:900 ~max_advance:4000
      |> found

let parse_error text () =
  match Seeds_database.of_json (Yojson.Safe.from_string text) with
  | Ok _ -> "ok"
  | Error e -> e

let () =
  Table_test.run "wild_target"
    [
      {
        name = "the shiny Ekans run's seed: its advance and waits";
        input = one_row;
        expectation =
          "seed BEF4 at 30756 ms, advance 1555: ekans Lv 15, nature 6, PID \
           26D0850C; csf 3348 ingame 19622";
      };
      {
        name = "the Sevii table: press 1837 is row 103, seed BEEC (BEF4 less 8)";
        input = table;
        expectation =
          "Mono / Help / A, 567 rows, 30756 ms: BEEC, 29032 ms: 1181";
      };
      {
        name = "the soonest shiny Ekans of the mGBA table";
        input = soonest;
        expectation =
          "seed 08F5 at 33050 ms, advance 988: ekans Lv 11, nature 6, PID \
           4DE0EE39; csf 3348 ingame 10129";
      };
      {
        name = "a seed file without Delay";
        input = parse_error {|{"Mono / Help / A": ["0000"]}|};
        expectation = "No Delay array in the seed file";
      };
      {
        name = "a bad seed";
        input = parse_error {|{"Delay": [1], "Mono / Help / A": ["XYZ"]}|};
        expectation = "Invalid seed value: XYZ";
      };
    ]
