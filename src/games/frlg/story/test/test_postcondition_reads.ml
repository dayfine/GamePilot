(* Postcondition_reads on a scripted screen (Scripted_screen): the party's
   species read member by member off the summary, from the overworld and back
   to it, and a plan that promises nothing reads nothing. *)

module S = Frlg_overworld_fixtures.Scripted_screen
module Party = Frlg_overworld_fixtures.Scripted_party

let names = [ "BLASTOISE"; "RATTATA"; "ODDISH"; "PIDGEY"; "ABRA"; "PIDGEY" ]
let levels = [ 52; 20; 18; 21; 33; 12 ]

(* The party on its summaries (Scripted_party). [lost_b] B presses on the
   member's menu after the summary are dropped (the menu still drawing). *)
let party_screen ?lost_b () =
  Party.react ?lost_b (List.map2 (fun n l -> Party.member n l) names levels)

let party_promised : Story.Plan.postconditions =
  {
    position = None;
    party = Some (Party_includes { members = [ "abra" ]; slots = [] });
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let observed_text (o : Story.Postcondition_check.observed) =
  match o.party with
  | None -> "party not read"
  | Some members ->
      String.concat ", " (List.map (Option.value ~default:"?") members)

let read_party ?lost_b () =
  let screen = S.create ~react:(party_screen ?lost_b ()) () in
  let observed =
    S.run screen (fun () ->
        Frlg_story.Postcondition_reads.observe ~log:ignore party_promised)
  in
  Printf.sprintf "%s; ends on %s" (observed_text observed)
    (S.screen_name (S.screen_at screen screen.S.clock_ms))

let nothing_promised () =
  let screen = S.create ~react:(party_screen ()) () in
  let observed =
    S.run screen (fun () ->
        Frlg_story.Postcondition_reads.observe ~log:ignore
          { party_promised with party = None })
  in
  Printf.sprintf "%s; %d presses" (observed_text observed)
    (List.length screen.S.presses)

(* START opens the menu on POKéMON; A on BAG (row 2) the Items pocket with
   [items] on its list; B from the bag back to the menu, from the menu to the
   overworld. *)
let bag_screen items screen (p : S.press) =
  let show s = S.show screen ~at_ms:(p.at_ms + 200) s in
  match (p.buttons, S.screen_at screen p.at_ms) with
  | [ Wire.Start ], _ -> show (S.Start_menu 0)
  | [ Wire.A ], S.Start_menu 2 -> show (S.Bag_items items)
  | [ Wire.B ], S.Bag_items _ -> show (S.Start_menu 2)
  | [ Wire.B ], S.Start_menu _ -> show S.Overworld
  | _ -> ()

let items_promised : Story.Plan.postconditions =
  {
    party_promised with
    party = None;
    items =
      [
        { bag_item = "revive"; count = Count_exactly 2 };
        { bag_item = "escape-rope"; count = Count_exactly 3 };
      ];
  }

let read_items items () =
  let screen = S.create ~react:(bag_screen items) () in
  let observed =
    S.run screen (fun () ->
        Frlg_story.Postcondition_reads.observe ~log:ignore items_promised)
  in
  Printf.sprintf "%s; ends on %s"
    (String.concat ", "
       (List.map (fun (i, n) -> Printf.sprintf "%s %d" i n) observed.items))
    (S.screen_name (S.screen_at screen screen.S.clock_ms))

(* At the start, only what a change is promised on: the Escape Ropes gained,
   not the Revives' exact count. *)
let read_at_start items () =
  let screen = S.create ~react:(bag_screen items) () in
  let promised =
    {
      items_promised with
      items =
        [
          { bag_item = "revive"; count = Count_exactly 2 };
          { bag_item = "escape-rope"; count = Count_gained 1 };
        ];
    }
  in
  let observed =
    S.run screen (fun () ->
        Frlg_story.Postcondition_reads.at_start ~log:ignore promised
          Story.Postcondition_check.nothing_read)
  in
  Printf.sprintf "%s; ends on %s"
    (String.concat ", "
       (List.map
          (fun (i, n) -> Printf.sprintf "%s %d" i n)
          observed.start_items))
    (S.screen_name (S.screen_at screen screen.S.clock_ms))

let read_level min () =
  let screen = S.create ~react:(party_screen ()) () in
  let promised =
    { party_promised with party = None; levels = [ { species = "abra"; min } ] }
  in
  let observed =
    S.run screen (fun () ->
        Frlg_story.Postcondition_reads.observe ~log:ignore promised)
  in
  Printf.sprintf "%s; ends on %s"
    (String.concat "; "
       (List.map Story.Postcondition_check.result_to_string
          (Story.Postcondition_check.check promised observed)))
    (S.screen_name (S.screen_at screen screen.S.clock_ms))

let cases : Table_test.case list =
  [
    {
      name = "each item's count read on its row of the bag";
      input = read_items [ ("POTION", 4); ("REVIVE", 2); ("ESCAPE ROPE", 13) ];
      expectation = "revive 2, escape-rope 13; ends on overworld";
    };
    {
      name = "an item the list ends without counts 0, not unread";
      input = read_items [ ("ESCAPE ROPE", 3) ];
      expectation = "revive 0, escape-rope 3; ends on overworld";
    };
    {
      name = "at the start, only the items promised as gained";
      input = read_at_start [ ("REVIVE", 2); ("ESCAPE ROPE", 4) ];
      expectation = "escape-rope 4; ends on overworld";
    };
    {
      name = "the party's species, slot 1 first, back on the overworld";
      input = read_party;
      expectation =
        "blastoise, rattata, oddish, pidgey, abra, pidgey; ends on overworld";
    };
    {
      name = "a B the member's menu drops is pressed again";
      input = read_party ~lost_b:1;
      expectation =
        "blastoise, rattata, oddish, pidgey, abra, pidgey; ends on overworld";
    };
    {
      name = "a member's level: the party read for its slot, then its summary";
      input = read_level 33;
      expectation = "level abra: passed: Lv 33; ends on overworld";
    };
    {
      name = "a member below its level";
      input = read_level 34;
      expectation =
        "level abra: failed: expected at least Lv 34, read Lv 33; ends on \
         overworld";
    };
    {
      name = "nothing promised, nothing read";
      input = nothing_promised;
      expectation = "party not read; 0 presses";
    };
  ]

let () = Table_test.run "postcondition_reads" cases
