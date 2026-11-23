type plan = { town : Fly_towns.town; slot : int; menu_row : int }

let fly_map_wait_ms = 4000
let member_menu_gone m = not (Party_actions.member_menu m)

let to_fly_map plan =
  Party_actions.open_party ();
  Party_actions.on_member_menu plan.slot (fun () ->
      Party_actions.choose_member_row (plan.menu_row - 1)
        ~taken:member_menu_gone);
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = fly_map_wait_ms } ]
      : Wire.batch_done)

let press button =
  Wire.Press
    {
      buttons = [ button ];
      hold_ms = Menu_input.button_hold_ms;
      cooldown_ms = 0;
    }

let fly_steps ~log plan =
  log
    (Printf.sprintf "Fly with slot %d, menu row %d, to %s (cell %d, %d)."
       plan.slot plan.menu_row plan.town.name plan.town.cell.x plan.town.cell.y);
  match to_fly_map plan with
  | exception Menu_input.Action_failed cause -> Error cause
  | () ->
      ignore
        (Effects.submit (Fly_towns.cursor_presses plan.town @ [ press Wire.A ]));
      Scene_looks.settle After_warp
        ~label:("fly to " ^ plan.town.name)
        ~battle_ends:false ~log

let fly ~log plan =
  Effects.with_probes Menu_input.probes (fun () -> fly_steps ~log plan)
