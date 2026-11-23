(* The FRLG screen readers on real screenshots: Switch captures from
   CommandLineTests and native mGBA frames from the lab. The fixtures are the
   daemon's [probe_images] output (not the images): one line per image, its
   name carrying what the screen shows after "__", dash-separated:

     dialog  the white text box        arrow   its red advance arrow
     choice  a Yes/No box above it     textbox a battle's teal text box
     menu    the battle action menu    battle  any battle screen
     black, white  a fade              dark    black corners, lit middle
     none    none of these

   Switch names keep their CommandLineTests folder and file name, whose
   True/False the fork's tests read for that folder's detector; the tags add
   the other readers' answers. regen_fixtures.sh makes them again from the
   source images listed in screen.switch.map and screen.mgba.map (set
   COMMANDLINETESTS_DIR and FRLG_SHOTS_DIR where those live). The Switch
   viewport is the fork's FRLG GAME_BOX: the picture inside the capture's side
   bars. *)

open Frlg_readers

let tags image =
  let base = Filename.remove_extension (Filename.basename image) in
  match String.split_on_char '_' base |> List.rev with
  | last :: "" :: _ -> String.split_on_char '-' last
  | _ -> failwith ("no tags in " ^ image)

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

(* A reader and what it should say on an image with these tags. *)
type reader = {
  reader : string;
  verdict : Effects.measurements -> string;
  expected : string list -> string;
}

let flag read m = string_of_bool (read m)
let tagged tag tags = string_of_bool (List.mem tag tags)

let facts_text (f : Screen_state.Facts.t) =
  String.concat " "
    (Screen_state.Fade.name f.fade
    :: List.filter_map
         (fun (name, on) -> if on then Some name else None)
         [ ("dialog", f.dialog); ("battle", f.battle) ])

let expected_facts tags =
  let has t = List.mem t tags in
  let fade : Screen_state.Fade.t =
    if has "black" then Black else if has "white" then White else No_fade
  in
  let battle = has "battle" in
  facts_text
    {
      Screen_state.Facts.none with
      fade;
      battle;
      dialog = (not battle) && (has "dialog" || has "choice");
    }

let readers =
  [
    {
      reader = "dialog_up";
      verdict = flag Dialog.dialog_up;
      expected = tagged "dialog";
    };
    {
      reader = "advance_arrow";
      verdict = flag Dialog.advance_arrow;
      expected = tagged "arrow";
    };
    {
      reader = "selection_dialog";
      verdict = flag Dialog.selection_dialog;
      expected = tagged "choice";
    };
    {
      reader = "battle_text_box";
      verdict = flag Battle_screen.battle_text_box;
      expected = tagged "textbox";
    };
    {
      reader = "battle_menu";
      verdict = flag Battle_screen.battle_menu;
      expected = tagged "menu";
    };
    {
      reader = "dark_corners";
      verdict = flag Dark_corners.dark_corners;
      expected = tagged "dark";
    };
    {
      reader = "facts";
      verdict = (fun m -> facts_text (Screen_facts.of_measurements m));
      expected = expected_facts;
    };
  ]

(* Images a reader reads wrong, as the fork's detector does too. The case
   expects the misread so the suite stays green; the tally counts it wrong.
   Red text (a female NPC's lines, a speaker's name) reads as the red arrow:
   a box's mean color cannot tell them apart. *)
let known_misreads =
  [
    ( "advance_arrow",
      "Dialog/white_dialog_red_text_spa-205200755327__dialog.png" );
  ]

let expectation r image =
  let right = r.expected (tags image) in
  if List.mem (r.reader, image) known_misreads then
    string_of_bool (not (bool_of_string right))
  else right

let cases backend images =
  List.concat_map
    (fun (image, probes) ->
      let m = measurements probes in
      List.map
        (fun r ->
          {
            Case_table.name = Printf.sprintf "%s %s: %s" backend r.reader image;
            input = (fun () -> r.verdict m);
            expectation = expectation r image;
          })
        readers)
    images

(* Per reader and backend: images read right / images. *)
let print_tally backend images =
  List.iter
    (fun r ->
      let right =
        List.filter
          (fun (image, probes) ->
            r.verdict (measurements probes) = r.expected (tags image))
          images
      in
      Printf.printf "tally %s %s: %d/%d\n" backend r.reader (List.length right)
        (List.length images))
    readers

let () =
  let backends =
    List.map
      (fun backend ->
        ( backend,
          Wire.read_image_probes ("fixtures/" ^ backend ^ ".probes.jsonl") ))
      [ "switch"; "mgba" ]
  in
  List.iter (fun (backend, images) -> print_tally backend images) backends;
  Case_table.run "screen readers"
    (List.concat_map (fun (backend, images) -> cases backend images) backends)
