(* The FRLG battle prompt readers on real screenshots: Switch captures from
   CommandLineTests and native mGBA frames from the lab, as for
   test_screen_readers.ml: run [regen_fixtures.sh battle], which reads
   battle.switch.map and battle.mgba.map. Each image's name carries what it
   shows after "__", dash-separated:

     yesno   a battle's YES/NO box       arrow   the battle text's red arrow
     learn   a YES/NO beside the player's HP box: a move to learn
     nopp    the move menu, its PP red   nohp    the battle text box with no
             HP box, arrow or YES/NO: what an evolution shows
     none    none of these

   Switch names keep their CommandLineTests folder and file name. *)

open Frlg_readers

let tags image =
  let base = Filename.remove_extension (Filename.basename image) in
  match String.split_on_char '_' base |> List.rev with
  | last :: "" :: _ -> String.split_on_char '-' last
  | _ -> failwith ("no tags in " ^ image)

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

type reader = {
  reader : string;
  verdict : Effects.measurements -> bool;
  tag : string;
}

let readers =
  [
    { reader = "yes_no_box"; verdict = Battle_yes_no.yes_no_box; tag = "yesno" };
    { reader = "move_learn"; verdict = Battle_yes_no.move_learn; tag = "learn" };
    {
      reader = "advance_arrow";
      verdict = Battle_text_arrow.advance_arrow;
      tag = "arrow";
    };
    { reader = "no_pp_left"; verdict = Move_pp.no_pp_left; tag = "nopp" };
    {
      reader = "evolution_shows";
      verdict = Evolution_screen.evolution_shows;
      tag = "nohp";
    };
  ]

let expected r image = List.mem r.tag (tags image)

let cases backend images =
  List.concat_map
    (fun r ->
      List.map
        (fun (image, probes) ->
          {
            Case_table.name = Printf.sprintf "%s %s: %s" backend r.reader image;
            input = (fun () -> string_of_bool (r.verdict (measurements probes)));
            expectation = string_of_bool (expected r image);
          })
        images)
    readers

(* Per reader and backend: images read right / images, and how many show it. *)
let print_tally backend images =
  List.iter
    (fun r ->
      let right =
        List.filter
          (fun (image, probes) ->
            r.verdict (measurements probes) = expected r image)
          images
      and shown = List.filter (fun (image, _) -> expected r image) images in
      Printf.printf "tally %s %s: %d/%d (%d showing it)\n" backend r.reader
        (List.length right) (List.length images) (List.length shown))
    readers

let () =
  let backends =
    List.map
      (fun backend ->
        ( backend,
          Wire.read_image_probes ("fixtures/battle." ^ backend ^ ".probes.jsonl")
        ))
      [ "switch"; "mgba" ]
  in
  List.iter (fun (backend, images) -> print_tally backend images) backends;
  Case_table.run "battle readers"
    (List.concat_map (fun (backend, images) -> cases backend images) backends)
