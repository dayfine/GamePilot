(* Identifying the hit advance against the C++'s golden vectors
   (fixtures/rng_calibration.txt): a starter's summary read in part, around an
   intended advance. *)

open Bdsp_rng

let records = Fixture_lines.read "fixtures/rng_calibration.txt"

let state = function
  | s0 :: s1 :: s2 :: s3 :: rest ->
      let word = Fixture_lines.hex in
      ( ({ s0 = word s0; s1 = word s1; s2 = word s2; s3 = word s3 }
          : Xorshift128.state),
        rest )
  | inputs -> failwith ("not a state: " ^ String.concat " " inputs)

let starter index =
  Rng_calibration.(
    match index with "0" -> Turtwig | "1" -> Chimchar | _ -> Piplup)

let starter_template : Static_encounter.template =
  {
    species = "starter";
    level = 5;
    guaranteed_ivs = 0;
    ability_kind = 3;
    gender_ratio = 31;
    shiny_locked = false;
  }

let adjustment_text nature stat_index =
  match Rng_calibration.nature_adjustment ~nature ~stat_index with
  | Neutral -> "="
  | Raised -> "+"
  | Lowered -> "-"

let nature_adjustment = function
  | [ nature ] ->
      List.init 6 (adjustment_text (int_of_string nature)) |> String.concat " "
  | _ -> failwith "nature_adjustment: nature"

let stats_text (s : int Rng_calibration.per_stat) =
  Printf.sprintf "%d %d %d %d %d %d" s.hp s.attack s.defense s.spatk s.spdef
    s.speed

let expected_stats inputs =
  match state inputs with
  | seed, [ index; advance; level ] ->
      let searcher =
        Static_encounter.searcher seed starter_template ~tsv:0
          ~synchronize_nature:None
      in
      Rng_calibration.expected_stats
        (Static_encounter.generate_at searcher (int_of_string advance))
        ~base_stats:(Rng_calibration.starter_base_stats (starter index))
        ~level:(int_of_string level)
      |> stats_text
  | _ -> failwith "expected_stats: state starter advance level"

let reading parse = function "-" -> None | text -> Some (parse text)

let gender = function
  | "M" -> Static_encounter.Male
  | "F" -> Female
  | _ -> Genderless

let observed index = function
  | [ nature; sex; shiny; hp; attack; defense; spatk; spdef; speed; level ] ->
      let stat = reading int_of_string in
      ({
         nature = reading int_of_string nature;
         gender = reading gender sex;
         shiny = reading (fun text -> text = "1") shiny;
         stats =
           {
             hp = stat hp;
             attack = stat attack;
             defense = stat defense;
             spatk = stat spatk;
             spdef = stat spdef;
             speed = stat speed;
           };
         base_stats = Rng_calibration.starter_base_stats (starter index);
         level = int_of_string level;
       }
        : Rng_calibration.observed)
  | inputs -> failwith ("not a reading: " ^ String.concat " " inputs)

let identify inputs =
  match state inputs with
  | seed, intended :: radius :: index :: reading -> (
      match
        Rng_calibration.identify_hit_advance seed starter_template
          ~intended_advance:(int_of_string intended)
          ~radius:(int_of_string radius) (observed index reading)
      with
      | Ok hit -> Printf.sprintf "1 %d %d 1 reason=" hit.advance hit.offset
      | Error miss ->
          Printf.sprintf "0 0 0 %d reason=%s" miss.candidates miss.reason)
  | _ -> failwith "identify: state intended radius starter reading"

let advances_between inputs =
  match state inputs with
  | from, rest -> (
      match state rest with
      | to_, [ search_max ] -> (
          match
            Rng_calibration.advances_between ~from ~to_
              ~search_max:(int_of_string search_max)
          with
          | Some advances -> Printf.sprintf "1 %d" advances
          | None -> "0 0")
      | _ -> failwith "advances_between: from to search_max")

let () =
  Fixture_lines.check_op records "nature_adjustment" nature_adjustment;
  Fixture_lines.check_op records "expected_stats" expected_stats;
  Fixture_lines.check_op records "identify" identify;
  Fixture_lines.check_op records "advances_between" advances_between;
  Table_test.finish ()
