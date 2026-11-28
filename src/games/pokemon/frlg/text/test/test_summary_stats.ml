(* Tests Summary_stats against real Switch Summary captures (sm3_s1.png and
   sm3_s2.png, Lv 16 Female Calm Squirtle with stats 45/21/29/25/33/23) probed
   by the daemon's probe_images tool. *)

open Frlg_text

let check_eq ~show name expected actual =
  if expected <> actual then (
    Printf.eprintf "FAIL %s\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual);
    exit 1)

let glyphs =
  match Data_files.locate Data_files.glyph_table with
  | Some path -> Glyph_table.load path
  | None -> failwith "glyph table not found"

let load_probes files =
  List.concat_map
    (fun file ->
      Wire.read_image_probes ("fixtures/" ^ file) |> List.concat_map snd)
    files

(* Runs an Effects computation against one static probe frame, matching every
   probe subscribed by Line_reading / Summary_stats. *)
let with_frame probes f =
  let m : Effects.measurements = { seq = 1; t_ms = 0.; probes } in
  Effect.Deep.match_with f ()
    {
      retc = Fun.id;
      exnc = raise;
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Effects.Upload_template _ ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  Effect.Deep.continue k "fake_hash")
          | Effects.Subscribe ps ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  Effect.Deep.continue k
                    (List.map (fun (p : Wire.probe_spec) -> p.id) ps))
          | Effects.Unsubscribe ids ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  Effect.Deep.continue k ids)
          | Effects.Await (condition, _) ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  let res =
                    if condition m then Effects.Holds m else Effects.Timeout
                  in
                  Effect.Deep.continue k res)
          | _ -> None);
    }

let show_int_opt = Option.fold ~none:"None" ~some:string_of_int

let show_gender_opt = function
  | None -> "None"
  | Some Summary_stats.Male -> "Some Male"
  | Some Female -> "Some Female"
  | Some Genderless -> "Some Genderless"

let test_switch_page1 () =
  let probes =
    load_probes
      [
        "summary_level_switch.probes.jsonl";
        "summary_nature_switch.probes.jsonl";
        "summary_gender_switch.probes.jsonl";
      ]
  in
  let level, nature, gender =
    with_frame probes (fun () ->
        ( Summary_stats.read_level glyphs,
          Summary_stats.read_nature glyphs,
          Summary_stats.read_gender () ))
  in
  check_eq ~show:show_int_opt "sm3_s1 level" (Some 16) level;
  check_eq ~show:show_int_opt "sm3_s1 nature (Calm=20)" (Some 20) nature;
  check_eq ~show:show_gender_opt "sm3_s1 gender (Female)" (Some Female) gender

let test_switch_page2 () =
  let probes =
    load_probes
      [ "summary_hp_switch.probes.jsonl"; "summary_stats_switch.probes.jsonl" ]
  in
  let stats = with_frame probes (fun () -> Summary_stats.read_stats glyphs) in
  match stats with
  | None -> failwith "expected sm3_s2 stats to read"
  | Some s ->
      check_eq ~show:string_of_int "sm3_s2 hp" 45 s.hp;
      check_eq ~show:string_of_int "sm3_s2 atk" 21 s.atk;
      check_eq ~show:string_of_int "sm3_s2 def" 29 s.def;
      check_eq ~show:string_of_int "sm3_s2 spa" 25 s.spa;
      check_eq ~show:string_of_int "sm3_s2 spd" 33 s.spd;
      check_eq ~show:string_of_int "sm3_s2 spe" 23 s.spe

let test_gender_classification () =
  let frame ~female ~male : Effects.measurements =
    {
      seq = 1;
      t_ms = 0.;
      probes =
        [
          ( "summary.gender.female",
            Color_count { fraction = female; mean = None } );
          ("summary.gender.male", Color_count { fraction = male; mean = None });
        ];
    }
  in
  check_eq ~show:show_gender_opt "male icon" (Some Male)
    (Summary_stats.gender_of_measurements (frame ~female:0.0 ~male:0.205));
  check_eq ~show:show_gender_opt "female icon" (Some Female)
    (Summary_stats.gender_of_measurements (frame ~female:0.152 ~male:0.0));
  check_eq ~show:show_gender_opt "genderless" (Some Genderless)
    (Summary_stats.gender_of_measurements (frame ~female:0.0 ~male:0.0))

let () =
  test_switch_page1 ();
  test_switch_page2 ();
  test_gender_classification ();
  print_endline "summary_stats: all passed"
