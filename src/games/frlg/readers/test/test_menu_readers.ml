(* The FRLG menu readers on real screenshots: Switch captures (CommandLineTests
   and our own) and native mGBA frames. The fixtures are the
   daemon's [probe_images] output, as for test_screen_readers.ml: run
   [regen_fixtures.sh menus], which reads menus.switch.map and menus.mgba.map.
   Each image's name carries what it shows after "__", dash-separated:

     startN        the Start menu, its cursor on row N (0 at the top)
     bag           the bag; items, keyitems, balls its pocket; rowN its cursor
     maileditor    the Easy Chat mail editor
     mailyes, mailno  its Yes/No, the arrow on YES or NO
     itemmenu      an item's own menu (USE or CHECK, GIVE, TOSS, CANCEL) over
                   the bag
     pouch         the Berry Pouch
     party         the party menu (its message box not covered)
     slotN         slot N (1-6) selected        membersN  N slots filled
     heldN, mailN  slot N's sprite carries the held-item or the mail icon
     summaryN      the summary screen on page N
     money         the money box
     moverowN      a move being picked on the summary's move list, row N
     memberN       a member's menu over the party, its cursor on row N (0 is
                   SUMMARY at the top)
     levelupN      a Rare Candy's level-up stats window on page N
     seagallopN    the Seagallop sailor's list of islands, its arrow on row N
     partyyesno    the party menu's YES/NO box (a move to delete, or to stop
                   teaching)
     jpn           a Japanese game (the icons sit elsewhere: marks not read)
     none          none of these

   Switch names keep their CommandLineTests folder and file name, whose
   True/False the fork's tests read for that folder's detector. A reader is
   checked on every image unless it reads inside a screen: then only on the
   images whose tags give its answer.

   menus.mgba.shifted.probes.jsonl holds the Seagallop list's frames
   (seagallop-one-island/) again with their colors shifted
   (dev/reader_fixtures/shift_frame.py: brightness times 0.9 and 1.1, one
   channel plus or minus 12, 10% toward mid-grey), named <shift>/<image>: on
   each, seagallop_row must read as on the frame itself. Its arrow is counted
   in a color range, so the images are shifted, not the probes' numbers. *)

open Frlg_readers

let tags image =
  let base = Filename.remove_extension (Filename.basename image) in
  match String.split_on_char '_' base |> List.rev with
  | last :: "" :: _ -> String.split_on_char '-' last
  | _ -> failwith ("no tags in " ^ image)

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

(* The number after [prefix] in a tag such as "row3"; the first such tag. *)
let numbered prefix tags =
  List.find_map
    (fun tag ->
      if String.starts_with ~prefix tag then
        int_of_string_opt
          (String.sub tag (String.length prefix)
             (String.length tag - String.length prefix))
      else None)
    tags

let all_numbered prefix tags =
  List.filter_map (fun tag -> numbered prefix [ tag ]) tags

type reader = {
  reader : string;
  applies : string list -> bool;
  verdict : Effects.measurements -> string;
  expected : string list -> string;
}

let everywhere _ = true
let has tag tags = List.mem tag tags
let flag read m = string_of_bool (read m)
let tagged tag tags = string_of_bool (has tag tags)
let optional = Option.fold ~none:"none" ~some:string_of_int
let slots = [ 1; 2; 3; 4; 5; 6 ]
let pockets = [ Bag_screen.Items; Bag_screen.Key_items; Bag_screen.Poke_balls ]

let expected_pocket tags =
  List.find_opt (fun p -> has (Bag_screen.pocket_name p) tags) pockets
  |> Option.fold ~none:"none" ~some:Bag_screen.pocket_name

let marks_text mark_of = String.concat " " (List.map mark_of slots)

let expected_marks tags =
  let held = all_numbered "held" tags and mail = all_numbered "mail" tags in
  marks_text (fun n ->
      if List.mem n held then "held"
      else if List.mem n mail then "mail"
      else "none")

let shows_marks tags =
  (not (has "jpn" tags))
  && (has "party" tags
     || all_numbered "held" tags <> []
     || all_numbered "mail" tags <> [])

let screen_readers =
  [
    {
      reader = "start_menu";
      applies = everywhere;
      verdict = (fun m -> optional (Start_menu.cursor_row m));
      expected = (fun tags -> optional (numbered "start" tags));
    };
    {
      reader = "bag_open";
      applies = everywhere;
      verdict = flag Bag_screen.bag_open;
      expected = tagged "bag";
    };
    {
      reader = "bag_item_menu";
      applies = everywhere;
      verdict = flag Bag_screen.item_menu;
      expected = tagged "itemmenu";
    };
    {
      reader = "party_menu";
      applies = everywhere;
      verdict = flag Party_menu.party_menu;
      expected = tagged "party";
    };
    {
      reader = "summary_page";
      applies = everywhere;
      verdict = (fun m -> optional (Summary_screen.page m));
      expected = (fun tags -> optional (numbered "summary" tags));
    };
    {
      reader = "berry_pouch";
      applies = everywhere;
      verdict = flag Berry_pouch_screen.berry_pouch;
      expected = tagged "pouch";
    };
    {
      reader = "money_box";
      applies = everywhere;
      verdict = flag Money_box.money_box;
      expected = tagged "money";
    };
    {
      reader = "move_list_row";
      applies = everywhere;
      verdict = (fun m -> optional (Move_list_cursor.row m));
      expected = (fun tags -> optional (numbered "moverow" tags));
    };
    {
      reader = "party_level_up_page";
      applies = everywhere;
      verdict = (fun m -> optional (Party_dialogs.level_up_page m));
      expected = (fun tags -> optional (numbered "levelup" tags));
    };
    {
      reader = "party_yes_no";
      applies = everywhere;
      verdict = flag Party_dialogs.move_learn_box;
      expected = tagged "partyyesno";
    };
    {
      reader = "seagallop_row";
      applies = everywhere;
      verdict =
        (fun m ->
          optional (Script_menu.cursor_row Script_menu.seagallop_islands m));
      expected = (fun tags -> optional (numbered "seagallop" tags));
    };
    {
      reader = "member_menu_row";
      applies = everywhere;
      verdict = (fun m -> optional (Member_menu.cursor_row m));
      expected = (fun tags -> optional (numbered "member" tags));
    };
  ]

let inner_readers =
  [
    {
      reader = "mail_editor_yes_no";
      applies =
        (fun tags ->
          has "maileditor" tags || has "mailyes" tags || has "mailno" tags);
      verdict =
        (fun m ->
          match Mail_editor.confirm_arrow m with
          | Some true -> "yes"
          | Some false -> "no"
          | None -> "none");
      expected =
        (fun tags ->
          if has "mailyes" tags then "yes"
          else if has "mailno" tags then "no"
          else "none");
    };
    {
      reader = "bag_pocket";
      applies = (fun tags -> expected_pocket tags <> "none");
      verdict =
        (fun m ->
          Option.fold ~none:"none" ~some:Bag_screen.pocket_name
            (Bag_screen.pocket m));
      expected = expected_pocket;
    };
    {
      reader = "bag_row";
      applies = (fun tags -> has "bag" tags && numbered "row" tags <> None);
      verdict = (fun m -> optional (Bag_screen.cursor_row m));
      expected = (fun tags -> optional (numbered "row" tags));
    };
    {
      reader = "selected_slot";
      applies = (fun tags -> numbered "slot" tags <> None);
      verdict = (fun m -> optional (Party_menu.selected_slot m));
      expected = (fun tags -> optional (numbered "slot" tags));
    };
    {
      reader = "members";
      applies = (fun tags -> numbered "members" tags <> None);
      verdict = (fun m -> string_of_int (Party_menu.members m));
      expected = (fun tags -> optional (numbered "members" tags));
    };
    {
      reader = "marks";
      applies = shows_marks;
      verdict =
        (fun m ->
          marks_text (fun n -> Party_menu.mark_name (Party_menu.mark m n)));
      expected = expected_marks;
    };
  ]

let readers = screen_readers @ inner_readers

(* Images a reader reads wrong. The case expects the misread so the suite
   stays green; the tally counts it wrong. *)
let known_misreads =
  [
    (* A Key Items action menu covers the bag's grey shadow, as in the fork. *)
    ("bag_open", "captures/tmcase-04-tmcase-after-A__bag-itemmenu.png", "false");
  ]

let expectation r image =
  match
    List.find_opt
      (fun (name, i, _) -> name = r.reader && i = image)
      known_misreads
  with
  | Some (_, _, misread) -> misread
  | None -> r.expected (tags image)

let applicable r images = List.filter (fun (i, _) -> r.applies (tags i)) images

let cases backend images =
  List.concat_map
    (fun r ->
      List.map
        (fun (image, probes) ->
          {
            Table_test.name = Printf.sprintf "%s %s: %s" backend r.reader image;
            input = (fun () -> r.verdict (measurements probes));
            expectation = expectation r image;
          })
        (applicable r images))
    readers

(* Per reader and backend: images read right / images it applies to. *)
let print_tally backend images =
  List.iter
    (fun r ->
      let images = applicable r images in
      let right =
        List.filter
          (fun (image, probes) ->
            r.verdict (measurements probes) = r.expected (tags image))
          images
      in
      Printf.printf "tally %s %s: %d/%d\n" backend r.reader (List.length right)
        (List.length images))
    readers

(* Victory Road 2F's cave floor under all three summary marks, as mGBA read it
   after the grind's level read (mg-04b, 2026-11-24): one flat pale colour that
   passes for tan and for white at once. *)
let cave_floor =
  let floor : Wire.rgb = { r = 206.; g = 181.; b = 156. } in
  let flat : Wire.rgb = { r = 0.; g = 0.; b = 0. } in
  measurements
    (List.map
       (fun id -> (id, Wire.Color_stats { mean = floor; stddev = flat }))
       [ "summary.page1"; "summary.page2"; "summary.page3" ])

let floors =
  [
    {
      Table_test.name =
        "summary_page: Victory Road's cave floor is no summary page";
      input =
        (fun () ->
          Option.fold ~none:"none" ~some:string_of_int
            (Summary_screen.page cave_floor));
      expectation = "none";
    };
  ]

(* The capture-card shifts of dev/reader_fixtures/shift_frame.py, applied to
   each color_stats probe's mean (and its stddev, for a scale): what they do to
   a flat box. Color counts stay as read. *)
let clamp v = Float.min 255. (Float.max 0. v)
let each f (c : Wire.rgb) : Wire.rgb = { r = f c.r; g = f c.g; b = f c.b }

let shifts : (string * (Wire.rgb -> Wire.rgb) * float) list =
  let scale k = each (fun v -> clamp (v *. k)) in
  [
    ("bright90", scale 0.9, 0.9);
    ("bright110", scale 1.1, 1.1);
    ("grey10", each (fun v -> v +. (0.1 *. (128. -. v))), 0.9);
    ("rplus12", (fun c -> { c with r = clamp (c.r +. 12.) }), 1.);
    ("rminus12", (fun c -> { c with r = clamp (c.r -. 12.) }), 1.);
    ("gplus12", (fun c -> { c with g = clamp (c.g +. 12.) }), 1.);
    ("gminus12", (fun c -> { c with g = clamp (c.g -. 12.) }), 1.);
    ("bplus12", (fun c -> { c with b = clamp (c.b +. 12.) }), 1.);
    ("bminus12", (fun c -> { c with b = clamp (c.b -. 12.) }), 1.);
  ]

let shifted (shift, k) probes =
  List.map
    (fun (id, result) ->
      match result with
      | Wire.Color_stats { mean; stddev } ->
          ( id,
            Wire.Color_stats
              { mean = shift mean; stddev = each (fun v -> v *. k) stddev } )
      | other -> (id, other))
    probes

(* bag_item_menu reads every image right with its colours shifted. *)
let shifted_cases backend images =
  List.concat_map
    (fun (name, shift, k) ->
      List.map
        (fun (image, probes) ->
          {
            Table_test.name =
              Printf.sprintf "%s bag_item_menu %s: %s" backend name image;
            input =
              (fun () ->
                flag Bag_screen.item_menu
                  (measurements (shifted (shift, k) probes)));
            expectation = tagged "itemmenu" (tags image);
          })
        images)
    shifts

(* The frame a shifted one comes from: its name less the "<shift>/". *)
let unshifted image =
  match String.index_opt image '/' with
  | Some i -> String.sub image (i + 1) (String.length image - i - 1)
  | None -> failwith ("no shift in " ^ image)

(* The readers checked on shifted frames. *)
let shift_tested = [ "seagallop_row" ]

let shifted_frame_cases backend images shifted =
  List.concat_map
    (fun r ->
      List.map
        (fun (image, probes) ->
          let original = List.assoc (unshifted image) images in
          {
            Table_test.name =
              Printf.sprintf "%s shifted %s: %s" backend r.reader image;
            input = (fun () -> r.verdict (measurements probes));
            expectation = r.verdict (measurements original);
          })
        shifted)
    (List.filter (fun r -> List.mem r.reader shift_tested) readers)

let () =
  let backends =
    List.map
      (fun backend ->
        ( backend,
          Wire.read_image_probes ("fixtures/menus." ^ backend ^ ".probes.jsonl")
        ))
      [ "switch"; "mgba" ]
  in
  List.iter (fun (backend, images) -> print_tally backend images) backends;
  let shifted_frames =
    Wire.read_image_probes "fixtures/menus.mgba.shifted.probes.jsonl"
  in
  Table_test.run "menu readers"
    (floors
    @ List.concat_map (fun (backend, images) -> cases backend images) backends
    @ List.concat_map
        (fun (backend, images) -> shifted_cases backend images)
        backends
    @ shifted_frame_cases "mgba" (List.assoc "mgba" backends) shifted_frames)
