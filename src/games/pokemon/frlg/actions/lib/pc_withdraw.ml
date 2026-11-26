open Frlg_readers
module Steps = Pc_withdraw_steps

let box_screen (v : Pc_screen.view) =
  match v.screen with Box_grid | Overworld -> true | _ -> false

let nothing : Steps.look =
  {
    view = { screen = Other; cursor = None };
    label = None;
    species = None;
    panel_empty = None;
    holds_item = None;
  }

(* PKMN DATA's species, whether it is blank and whether it names an item, on
   a box screen only. *)
let panel m : Steps.look -> Steps.look =
 fun l ->
  {
    l with
    species = Pc_deposit.species_shown ();
    panel_empty = Option.map not (Pc_box_screen.panel_occupied m);
    holds_item = Pc_box_screen.holds_item m;
  }

let look_at m : Steps.look =
  let view = Pc_screen.read m in
  let l = { nothing with view; label = Pc_deposit.label view } in
  if box_screen view then panel m l else l

let look () = Option.fold ~none:nothing ~some:look_at (Effects.read ())

let describe (l : Steps.look) =
  Printf.sprintf "%s (cursor %s%s%s%s)"
    (Pc_screen.screen_name l.view.screen)
    (Option.fold ~none:"-" ~some:string_of_int l.view.cursor)
    (Option.fold ~none:"" ~some:(fun s -> ", " ^ s) l.label)
    (Option.fold ~none:"" ~some:(fun s -> ", " ^ s) l.species)
    (match l.holds_item with
    | Some true -> ", holds an item"
    | Some false -> ", holds nothing"
    | None -> "")

let rec run ~log steps left =
  if left = 0 then
    Menu_input.fail "pc_withdraw" "not back on the overworld in time"
  else
    let l = look () in
    let steps, p = Steps.next steps l in
    log
      (Printf.sprintf "PC: %s: %s." (describe l)
         (Pc_deposit_steps.press_to_string p));
    match (p, Steps.withdrawn steps) with
    | Done, Some species -> species
    | Done, None -> Menu_input.fail "pc_withdraw" "done before a withdraw"
    | Fail why, _ ->
        Menu_input.fail "pc_withdraw"
          (Pc_screen.screen_name l.view.screen ^ ": " ^ why)
    | p, _ ->
        Pc_deposit.press p;
        run ~log steps (left - 1)

let withdraw ~log =
  let species =
    Effects.with_probes (Pc_screen.probes @ Pc_box_screen.probes) (fun () ->
        run ~log Steps.start Steps.max_looks)
  in
  log ("PC: withdrew " ^ species ^ ".");
  species
