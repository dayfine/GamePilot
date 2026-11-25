open Frlg_readers
module M = Menu_input
module J = Json_field
module Text = Frlg_text

let mail = "retro-mail"
let fields_checked = 4
let bag_or_party m = Bag_screen.bag_open m || Party_menu.party_menu m

(* The editor opening: the fork's measured wait, then the fields are read. *)
let await_editor () =
  ignore
    (Effects.submit
       [ Wire.Wait { wait_ms = Party_actions.mail_editor_wait_ms } ])

let write_glitched_mail ~log ~slot words =
  log (Printf.sprintf "ACE: Retro Mail to slot %d, the ? Mail's words." slot);
  Bag_items.item_action mail (Party_actions.give_row mail);
  Party_actions.give_to slot;
  await_editor ();
  Easy_chat_entry.check_unchanged ~count:fields_checked;
  Effects.save_run_frame "ace-mail-before.png";
  log "ACE: the editor shows the ? Mail (???).";
  Easy_chat_entry.write ~log words;
  Effects.save_run_frame "ace-mail-typed.png";
  M.press Wire.Start;
  Party_actions.confirm_mail ();
  log "ACE: the message confirmed.";
  M.close_through_fades "the bag" bag_or_party;
  M.settle_back ~label:"write glitched mail" ~log

type slot_check = {
  box : int;
  slot : int;
  occupied : bool;
  level : int option;
  male : bool option;
}

let box_change_ms = 900
let hand_ms = 400
let slots_per_row = 6
let title_down_col = 2
let pc_fail why = M.fail "pc_box" why
let step_hold_ms = 160

let step ms button =
  ignore
    (Effects.submit [ M.hold ~hold_ms:step_hold_ms ~cooldown_ms:ms button ])

let wallpaper () =
  ignore (Effects.submit [ Wire.Wait { wait_ms = hand_ms } ]);
  match Effects.read () with
  | Some m when Pc_box_screen.desert_wallpaper m = Some true -> `Desert
  | Some m when Pc_box_screen.forest_wallpaper m = Some true -> `Forest
  | _ -> `Other

(* MOVE POKéMON opens on the box last shown (the save's current box), on its
   first slot: UP to the title; from Box 1 (Forest) RIGHT twice to Box 3
   (Desert); DOWN onto the row's third slot, across, down. *)
let to_slot c =
  step hand_ms Wire.Up;
  (match wallpaper () with
  | `Desert -> ()
  | `Forest ->
      step box_change_ms Wire.Right;
      step box_change_ms Wire.Right
  | `Other -> pc_fail "the box shown is neither Box 1 nor Box 3 (by wallpaper)");
  step hand_ms Wire.Down;
  let col = (c.slot - 1) mod slots_per_row
  and row = (c.slot - 1) / slots_per_row in
  let across = col - title_down_col in
  for _ = 1 to abs across do
    step hand_ms (if across < 0 then Wire.Left else Wire.Right)
  done;
  for _ = 1 to row do
    step hand_ms Wire.Down
  done

let level_reads level =
  let digits = string_of_int level in
  match
    Text.Line_reading.read ~ink:Text.Line_reading.light_ink
      (Text_data.glyphs ()) Text.Text_lines.pc_data_level [ digits ]
  with
  | Read _ -> true
  | No_match _ -> false

type box_view = {
  panel_occupied : bool option;
  desert : bool option;
  hand_on_first_slot : bool option;
  male : bool option;
  level_shown : int -> bool;
}

type verdict = As_asked | Wrong of string | Unread of string

let box_view m =
  {
    panel_occupied = Pc_box_screen.panel_occupied m;
    desert = Pc_box_screen.desert_wallpaper m;
    hand_on_first_slot = Pc_box_screen.hand_on_first_slot m;
    male = Pc_box_screen.male m;
    level_shown = level_reads;
  }

let asked (c : slot_check) ~occupied (v : box_view) =
  if occupied <> c.occupied then
    Wrong
      (Printf.sprintf "slot %d is %s" c.slot
         (if occupied then "occupied" else "empty"))
  else if (not occupied) && v.hand_on_first_slot <> Some true && c.slot = 1 then
    Wrong "the hand is not on the first slot"
  else if
    occupied
    && Option.fold ~none:false ~some:(fun male -> v.male <> Some male) c.male
  then Wrong "the gender mark is not as asked"
  else if
    occupied
    && Option.fold ~none:false ~some:(fun l -> not (v.level_shown l)) c.level
  then Wrong "the level is not as asked"
  else As_asked

let slot_verdict (c : slot_check) (v : box_view) =
  match (v.panel_occupied, v.desert) with
  | None, _ -> Unread "PKMN DATA did not read"
  | _, None -> Unread "the wallpaper did not read"
  | _, Some false ->
      Wrong (Printf.sprintf "BOX %d's Desert wallpaper is not shown" c.box)
  | Some occupied, Some true -> asked c ~occupied v

let report ~log c = function
  | As_asked ->
      log
        (Printf.sprintf "PC: BOX %d slot %d is %s, as expected." c.box c.slot
           (if c.occupied then "occupied" else "empty"))
  | Wrong why | Unread why -> M.fail "box_slot_wrong" why

let look_at_slot ~log c =
  Pc_box.to_box_screen ~log Pc_box.screen_game_steps;
  to_slot c;
  ignore (Effects.submit [ Wire.Wait { wait_ms = hand_ms } ]);
  Effects.save_run_frame (Printf.sprintf "box%d-slot%d.png" c.box c.slot);
  let v =
    match Effects.read () with
    | Some m -> slot_verdict c (box_view m)
    | None -> Wrong "no frame"
  in
  (match v with Unread why -> pc_fail why | As_asked | Wrong _ -> ());
  Pc_box.leave ~log Pc_box.screen_game_steps;
  v

let check_box_slot ~log c =
  if c.box <> 3 then
    M.fail ~repeats:true "bad_args" "check_box_slot: box 3 only";
  let v =
    Effects.with_probes (Pc_screen.probes @ Pc_box_screen.probes) (fun () ->
        look_at_slot ~log c)
  in
  M.settle_back ~label:"pc box" ~log;
  report ~log c v

let words ~where args =
  J.records ~where "words" args (fun ~where w ->
      {
        Easy_chat_entry.group = J.string ~where "group" w;
        word = J.string ~where "word" w;
      })

let int_opt ~where key args =
  if J.has key args then Some (J.int ~where key args) else None

let slot_check ~where args =
  {
    box = J.int ~where "box" args;
    slot = J.int ~where "slot" args;
    occupied = J.bool_or ~where ~default:false "occupied" args;
    level = int_opt ~where "level" args;
    male =
      (if J.has "male" args then
         Some (J.bool_or ~where ~default:false "male" args)
       else None);
  }

let run_with ~action read perform args =
  Result.bind (Action_args.decode ~action read args) (fun v ->
      M.run (fun () -> perform v))

let on_member party ~action read perform (_ : Pokemon_checkpoints.Plan.event)
    args =
  run_with ~action
    (fun ~where args -> (Action_args.member ~where args, read ~where args))
    (fun (member, v) ->
      match Party_roster.resolve !party member with
      | Ok slot -> perform slot v
      | Error cause -> M.raise_error (Error cause))
    args

let handlers ~log ~party =
  [
    ( "write_glitched_mail",
      on_member party ~action:"write_glitched_mail" words (fun slot ws ->
          write_glitched_mail ~log ~slot ws) );
    ( "check_box_slot",
      fun (_ : Pokemon_checkpoints.Plan.event) args ->
        run_with ~action:"check_box_slot" slot_check (check_box_slot ~log) args
    );
  ]
