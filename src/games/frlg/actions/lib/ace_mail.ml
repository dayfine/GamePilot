open Frlg_readers
module M = Menu_input
module J = Json_field
module Text = Frlg_text
module Steps = Pc_deposit_steps

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
  Bag_items.item_action mail Party_actions.give_row;
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

(* MOVE POKéMON is the storage menu's third row. *)
let move_row = 2
let move_label = "MOVE POKéMON"
let max_looks = 40
let box_change_ms = 900
let hand_ms = 400
let slots_per_row = 6
let title_down_col = 2
let pc_fail why = M.fail "pc_box" why

(* From the overworld facing the PC to the box screen, read look by look. The
   box screen with a Pokémon's data in PKMN DATA reads as the overworld
   ({!Pc_screen} knows the deposit's screens): once A went in on MOVE POKéMON,
   a settled frame that is not the storage menu is the box screen. *)
let rec to_box_screen ~log ~booted ?(chosen = false) looks =
  if looks = 0 then pc_fail "the box screen did not open"
  else
    let (l : Steps.look) = Pc_deposit.look () in
    log ("PC: " ^ Pc_screen.screen_name l.view.screen ^ ".");
    let again ?(chosen = chosen) () =
      to_box_screen ~log ~booted:true ~chosen (looks - 1)
    in
    match (l.view.screen, l.view.cursor) with
    | Box_grid, _ -> log "PC: the box screen."
    | Overworld, _ when chosen -> log "PC: the box screen."
    | Overworld, _ when not booted ->
        Pc_deposit.press A;
        again ()
    | Text, _ ->
        Pc_deposit.press B;
        again ()
    | Pc_list, Some 0
      when List.exists (fun t -> l.label = Some t) Steps.pc_list_tops ->
        Pc_deposit.press A;
        again ()
    | Pc_list, Some _ ->
        Pc_deposit.press Up;
        again ()
    | Storage_menu, Some c when c = move_row && l.label = Some move_label ->
        Pc_deposit.press A;
        again ~chosen:true ()
    | Storage_menu, Some c when c < move_row ->
        Pc_deposit.press Down;
        again ()
    | Storage_menu, Some _ ->
        Pc_deposit.press Up;
        again ()
    | _ ->
        Pc_deposit.press Wait;
        again ()

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

let read_or name = function
  | Some v -> v
  | None -> pc_fail (name ^ " did not read")

let verdict c m =
  let occupied = read_or "PKMN DATA" (Pc_box_screen.panel_occupied m) in
  let desert = read_or "the wallpaper" (Pc_box_screen.desert_wallpaper m) in
  if not desert then
    Some (Printf.sprintf "BOX %d's Desert wallpaper is not shown" c.box)
  else if occupied <> c.occupied then
    Some
      (Printf.sprintf "slot %d is %s" c.slot
         (if occupied then "occupied" else "empty"))
  else if
    (not occupied)
    && Pc_box_screen.hand_on_first_slot m <> Some true
    && c.slot = 1
  then Some "the hand is not on the first slot"
  else if
    occupied
    && Option.fold ~none:false
         ~some:(fun male -> Pc_box_screen.male m <> Some male)
         c.male
  then Some "the gender mark is not as asked"
  else if
    occupied
    && Option.fold ~none:false ~some:(fun l -> not (level_reads l)) c.level
  then Some "the level is not as asked"
  else None

let rec leave ~log looks =
  if looks = 0 then pc_fail "the overworld did not come back"
  else
    let (l : Steps.look) = Pc_deposit.look () in
    match l.view.screen with
    | Overworld -> log "PC: back on the overworld."
    | Other ->
        Pc_deposit.press Wait;
        leave ~log (looks - 1)
    | _ ->
        Pc_deposit.press B;
        leave ~log (looks - 1)

(* B leaves the box screen first: it can read as the overworld. *)
let back_out ~log looks =
  Pc_deposit.press B;
  leave ~log looks

let report ~log c = function
  | None ->
      log
        (Printf.sprintf "PC: BOX %d slot %d is %s, as expected." c.box c.slot
           (if c.occupied then "occupied" else "empty"))
  | Some why -> M.fail "box_slot_wrong" why

let look_at_slot ~log c =
  to_box_screen ~log ~booted:false max_looks;
  to_slot c;
  ignore (Effects.submit [ Wire.Wait { wait_ms = hand_ms } ]);
  Effects.save_run_frame (Printf.sprintf "box%d-slot%d.png" c.box c.slot);
  let v =
    match Effects.read () with Some m -> verdict c m | None -> Some "no frame"
  in
  back_out ~log max_looks;
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
