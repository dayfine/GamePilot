open Frlg_readers
module M = Menu_input
module J = Grid_maps.Json_field

let mark_of_name : string -> Party_menu.mark option = function
  | "held_item" -> Some Held_item
  | "mail" -> Some Mail
  | "none" -> Some No_mark
  | _ -> None

let mismatch ~read slot mark =
  let shown = read slot in
  if shown = mark then None
  else
    Some
      (Printf.sprintf "slot %d shows %s, not %s" slot
         (Party_menu.mark_name shown)
         (Party_menu.mark_name mark))

let marks_mismatch expected ~read =
  List.mapi (fun i mark -> (i + 1, mark)) expected
  |> List.find_map (fun (slot, mark) -> mismatch ~read slot mark)

let check_marks ~log expected =
  Party_actions.open_party ();
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = Party_actions.party_settle_ms } ]);
  let m = M.await_screen ~code:"no_party" "the party" Party_menu.party_menu in
  let mismatch = marks_mismatch expected ~read:(Party_menu.mark m) in
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"party marks" ~log;
  match mismatch with
  | None -> log "Party: the marks are as expected."
  | Some detail -> M.fail "party_marks_wrong" detail

let mail = "retro-mail"
let bag_or_party m = Bag_screen.bag_open m || Party_menu.party_menu m

let read_glitched_mail ~log ~slot ~word =
  log (Printf.sprintf "Mail: give Retro Mail to slot %d, read the mail." slot);
  Bag_items.item_action mail Party_actions.give_row;
  ignore
    (M.await_screen ~code:"no_party" "the party to give to"
       Party_menu.party_menu);
  Party_actions.choose_slot slot;
  M.answer_yes ~code:"no_switch_question" "the switch question";
  Item_duplication.check_editor ~word;
  log ("Mail: the editor reads " ^ word ^ " in field 1 (proof A).");
  M.press Wire.Start;
  Party_actions.confirm_mail ();
  M.close "the bag" bag_or_party;
  M.settle_back ~label:"read glitched mail" ~log

let move_to_top ~log item =
  Bag_items.open_pocket_top (Bag_items.pocket_of_item item);
  (match Bag_items.list_row item with
  | None -> M.fail "not_in_bag" (item ^ " is not in the bag")
  | Some 0 -> log ("Bag: " ^ item ^ " is on top already.")
  | Some k ->
      log (Printf.sprintf "Bag: move %s from row %d to the top." item k);
      Bag_items.to_top ();
      Bag_items.select item;
      M.press Wire.Select;
      M.taps Wire.Up k;
      Bag_items.to_top ();
      M.press Wire.Select;
      Bag_items.to_top ();
      if Bag_items.list_row item <> Some 0 then
        M.fail "item_not_on_top" (item ^ " did not move to the top"));
  M.close "the bag" Bag_screen.bag_open;
  M.settle_back ~label:"move item" ~log

let marks ~where args =
  let mark name =
    match mark_of_name name with
    | Some mark -> mark
    | None -> J.fail "%smarks: %s is no mark." where name
  in
  List.map mark (J.strings (where ^ "marks") (J.field ~where "marks" args))

let duplication_plan ~where args : Item_duplication.plan =
  {
    item = J.string ~where "item" args;
    rounds = J.int ~where "count" args;
    word = J.string ~where "word" args;
  }

let run_with ~action read perform args =
  Result.bind (Action_args.decode ~action read args) (fun v ->
      M.run (fun () -> perform v))

let on_slot party ~action read perform =
  let decode ~where args = (Action_args.member ~where args, read ~where args) in
  fun (_ : Story.Plan.event) args ->
    run_with ~action decode
      (fun (member, v) ->
        match Party_roster.resolve !party member with
        | Ok slot -> perform slot v
        | Error cause -> raise (M.Action_failed cause))
      args

let duplicate ~log slot plan =
  if slot <> 1 then
    M.fail ~repeats:true "bad_args"
      (Printf.sprintf "duplicate_item: the holder is in slot %d, not 1" slot);
  Item_duplication.run ~log plan

let handlers ~log ~party =
  let simple action read perform (_ : Story.Plan.event) args =
    run_with ~action read perform args
  in
  [
    ("check_party_marks", simple "check_party_marks" marks (check_marks ~log));
    ( "read_glitched_mail",
      on_slot party ~action:"read_glitched_mail"
        (fun ~where args -> J.string ~where "word" args)
        (fun slot word -> read_glitched_mail ~log ~slot ~word) );
    ( "move_item_to_top",
      simple "move_item_to_top"
        (fun ~where args -> J.string ~where "item" args)
        (move_to_top ~log) );
    ( "duplicate_item",
      on_slot party ~action:"duplicate_item" duplication_plan (duplicate ~log)
    );
  ]
