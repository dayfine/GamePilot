(* Postcondition_reads on a scripted screen (Scripted_screen): the party's
   species read member by member off the summary, from the overworld and back
   to it, and a plan that promises nothing reads nothing. *)

module S = Frlg_overworld_fixtures.Scripted_screen

let names = [ "BLASTOISE"; "RATTATA"; "ODDISH"; "PIDGEY"; "ABRA"; "PIDGEY" ]

(* START opens the menu on POKéMON; A on it the party; A on a slot its menu;
   A on SUMMARY (row 0) the slot's species. B steps back one screen: from the
   summary to the member's menu, from the menu to the party, from the party to
   the overworld. [lost_b] B presses on the member's menu after the summary
   are dropped (the menu still drawing). *)
let party_screen ?(lost_b = 0) () =
  let slot = ref 1 and dropped = ref 0 in
  fun screen (p : S.press) ->
    let show s = S.show screen ~at_ms:(p.at_ms + 200) s in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.Start ], _ -> show (S.Start_menu 1)
    | [ Wire.A ], S.Start_menu 1 -> show (S.Party 1)
    | [ Wire.A ], S.Party s ->
        slot := s;
        show (S.Member_menu 0)
    | [ Wire.A ], S.Member_menu 0 ->
        show (S.Summary (List.nth names (!slot - 1)))
    | [ Wire.B ], S.Summary _ -> show (S.Member_menu 0)
    | [ Wire.B ], S.Member_menu _ when !dropped < lost_b -> incr dropped
    | [ Wire.B ], S.Member_menu _ -> show (S.Party !slot)
    | [ Wire.B ], S.Party _ -> show S.Overworld
    | _ -> ()

let party_promised : Story.Plan.postconditions =
  {
    position = None;
    party = Some (Party_includes [ "abra" ]);
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
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
        { item = "revive"; quantity = 2 };
        { item = "escape-rope"; quantity = 3 };
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

let cases : Case_table.case list =
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
      name = "nothing promised, nothing read";
      input = nothing_promised;
      expectation = "party not read; 0 presses";
    };
  ]

let () = Case_table.run "postcondition_reads" cases
