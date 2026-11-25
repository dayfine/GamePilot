(* The FRLG battle prompt readers on real screenshots: Switch captures from
   CommandLineTests and native mGBA frames from the lab, as for
   test_screen_readers.ml: run [regen_fixtures.sh battle], which reads
   battle.switch.map and battle.mgba.map. Each image's name carries what it
   shows after "__", dash-separated:

     yesno   a battle's YES/NO box       arrow   the battle text's red arrow
     learn   a YES/NO beside the player's HP box: a move to learn
     nopp    the move menu, its PP red   nohp    the battle text box with no
             HP box, arrow or YES/NO: what an evolution shows
     ally    a double battle's HP boxes on the player's side
     caught  the Poké Ball mark on a wild foe's HP box: its species caught
     none    none of these

   Switch names keep their CommandLineTests folder and file name. A trainer's
   "Will ... change POKéMON?" (three-island-bikers/switch-offer, the Shift
   battle style) is tagged learn: its YES/NO stands where a move learn's does,
   beside the player's HP box, and only its text tells the two apart
   (Frlg_actions.Switch_offer).

   battle.<backend>.shifted.probes.jsonl holds the frames of dex-route10/
   again with their colors shifted (dev/reader_fixtures/shift_frame.py:
   brightness times 0.9 and 1.1, each channel 12 up and down, 10% toward
   mid-grey): the caught mark must read on each as on its frame. *)

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
    { reader = "ally_boxes"; verdict = Battle_screen.ally_boxes; tag = "ally" };
    { reader = "caught_mark"; verdict = Caught_mark.caught; tag = "caught" };
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
            Table_test.name = Printf.sprintf "%s %s: %s" backend r.reader image;
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

(* The frame a shifted one comes from: its name less the "<shift>/". *)
let unshifted image =
  match String.index_opt image '/' with
  | Some i -> String.sub image (i + 1) (String.length image - i - 1)
  | None -> failwith ("no shift in " ^ image)

let shifted_cases backend shifted =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name =
          Printf.sprintf "%s shifted caught_mark: %s" backend image;
        input =
          (fun () -> string_of_bool (Caught_mark.caught (measurements probes)));
        expectation =
          string_of_bool (List.mem "caught" (tags (unshifted image)));
      })
    shifted

let shifted backend =
  let file = "fixtures/battle." ^ backend ^ ".shifted.probes.jsonl" in
  if Sys.file_exists file then Wire.read_image_probes file else []

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
  Table_test.run "battle readers"
    (List.concat_map
       (fun (backend, images) ->
         cases backend images @ shifted_cases backend (shifted backend))
       backends)
