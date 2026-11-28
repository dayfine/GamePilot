module P = Switch.Switch_presses

let ( let* ) = Result.bind

type pocket_snapshot = {
  pocket : Bdsp_readers.Bag_pocket_reader.pocket;
  pages : int;
}

type game_steps = {
  open_bag : unit -> (unit, string) result;
  switch_pocket :
    from:Bdsp_readers.Bag_pocket_reader.pocket ->
    to_:Bdsp_readers.Bag_pocket_reader.pocket ->
    unit;
  scroll_page : unit -> unit;
  snapshot : pocket:Bdsp_readers.Bag_pocket_reader.pocket -> page:int -> unit;
  close_bag : unit -> unit;
}

let rec validate_plan = function
  | [] -> Ok ()
  | entry :: rest ->
      if entry.pages < 1 then
        Error
          (Printf.sprintf "check_bag: pages %d must be at least 1" entry.pages)
      else validate_plan rest

let visit_entry steps current_pocket (entry : pocket_snapshot) =
  if entry.pocket <> current_pocket then
    steps.switch_pocket ~from:current_pocket ~to_:entry.pocket;
  for page = 1 to entry.pages do
    steps.snapshot ~pocket:entry.pocket ~page;
    if page < entry.pages then steps.scroll_page ()
  done;
  entry.pocket

let visit_all steps start_pocket plan =
  let step (cur, count) entry =
    let next_pocket = visit_entry steps cur entry in
    (next_pocket, count + entry.pages)
  in
  snd (List.fold_left step (start_pocket, 0) plan)

let run steps ~start_pocket plan =
  let* () = validate_plan plan in
  match plan with
  | [] -> Ok 0
  | _ ->
      let* () = steps.open_bag () in
      let total = visit_all steps start_pocket plan in
      steps.close_bag ();
      Ok total

let repeat_bag_press btn n =
  let bag = Overworld_timing.bag in
  for _ = 1 to max 0 n do
    P.press ~hold_ms:bag.nav_hold_ms ~cooldown_ms:bag.nav_cooldown_ms btn
  done

let live_game_steps ~log ~on_snapshot ~picture =
  let bag = Overworld_timing.bag in
  let open_bag () =
    log "Opening Bag...";
    let* () = Overworld_actions.open_menu ~log ~picture () in
    let* () = Overworld_actions.menu_select ~log ~picture ~dx:0 ~dy:0 () in
    P.wait Overworld_timing.dlg.bag_open_wait_ms;
    Ok ()
  in
  let switch_pocket ~from ~to_ =
    match Bdsp_readers.Bag_pocket_reader.pocket_steps ~from ~to_ with
    | `Stay -> ()
    | `Right n ->
        repeat_bag_press Wire.Right n;
        P.wait bag.page_wait_ms
    | `Left n ->
        repeat_bag_press Wire.Left n;
        P.wait bag.page_wait_ms
  in
  let scroll_page () =
    repeat_bag_press Wire.Down bag.page_rows;
    P.wait bag.page_wait_ms
  in
  let snapshot ~pocket ~page =
    P.wait bag.page_wait_ms;
    on_snapshot ~pocket ~page
  in
  let close_bag () =
    log "Closing Bag back to overworld...";
    for _ = 1 to bag.exit_presses do
      P.press ~hold_ms:bag.nav_hold_ms ~cooldown_ms:bag.exit_cooldown_ms Wire.B
    done
  in
  { open_bag; switch_pocket; scroll_page; snapshot; close_bag }
