open Frlg_readers
module Steps = Pc_deposit_steps

type game_steps = { look : unit -> Steps.look; press : Steps.press -> unit }

let screen_game_steps = { look = Pc_deposit.look; press = Pc_deposit.press }

type opening = { booted : bool; chosen : bool }

let opening = { booted = false; chosen = false }

type next = At_box_screen | Press of Steps.press * opening

(* MOVE POKéMON is the storage menu's third row. *)
let move_row = 2
let move_label = "MOVE POKéMON"
let max_looks = 40

let pc_top (l : Steps.look) =
  List.exists (fun t -> l.label = Some t) Steps.pc_list_tops

let open_next o (l : Steps.look) =
  let on = { o with booted = true } in
  match (l.view.screen, l.view.cursor) with
  | Box_grid, _ -> At_box_screen
  | Overworld, _ when o.chosen -> At_box_screen
  | Overworld, _ when not o.booted -> Press (A, on)
  | Text, _ -> Press (B, on)
  | Pc_list, Some 0 when pc_top l -> Press (A, on)
  | Pc_list, Some _ -> Press (Up, on)
  | Storage_menu, Some c when c = move_row && l.label = Some move_label ->
      Press (A, { on with chosen = true })
  | Storage_menu, Some c when c < move_row -> Press (Down, on)
  | Storage_menu, Some _ -> Press (Up, on)
  | _ -> Press (Wait, on)

let leave_next (l : Steps.look) : Steps.press option =
  match l.view.screen with
  | Overworld -> None
  | Other -> Some Wait
  | _ -> Some B

let pc_fail why = Menu_input.fail "pc_box" why

let rec open_from ~log steps o looks =
  if looks = 0 then pc_fail "the box screen did not open"
  else
    let l = steps.look () in
    log ("PC: " ^ Pc_screen.screen_name l.view.screen ^ ".");
    match open_next o l with
    | At_box_screen -> log "PC: the box screen."
    | Press (p, o) ->
        steps.press p;
        open_from ~log steps o (looks - 1)

let to_box_screen ~log steps = open_from ~log steps opening max_looks

let rec leave_from ~log steps looks =
  if looks = 0 then pc_fail "the overworld did not come back"
  else
    match leave_next (steps.look ()) with
    | None -> log "PC: back on the overworld."
    | Some p ->
        steps.press p;
        leave_from ~log steps (looks - 1)

let leave ~log steps =
  steps.press B;
  leave_from ~log steps max_looks
