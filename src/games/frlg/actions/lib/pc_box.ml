open Frlg_readers
module Steps = Pc_deposit_steps
module Text = Frlg_text

type target = Move_pokemon | Withdraw_item
type look = { pc : Steps.look; menu_top : string option; item_list : bool }
type game_steps = { look : target -> look; press : Steps.press -> unit }
type opening = { booted : bool; chosen : bool; message_seen : bool }

let opening = { booted = false; chosen = false; message_seen = false }

type next = Opened | Press of Steps.press * opening

(* MOVE POKéMON is the storage menu's third row. *)
let move_row = 2
let move_label = "MOVE POKéMON"

(* pokefirered pc.inc: the PC list's second row is the player's PC; player_pc.c
   opens its menu (ITEM STORAGE, MAILBOX, TURN OFF) and ITEM STORAGE's (WITHDRAW
   ITEM, DEPOSIT ITEM, CANCEL) with the cursor on the top row
   ([Task_DrawPlayerPcTopMenu], [Task_CreateItemStorageSubmenu]). *)
let player_pc_row = 1
let item_storage = "ITEM STORAGE"
let withdraw_item = "WITHDRAW ITEM"
let player_pc_menu_tops = [ item_storage; withdraw_item ]
let max_looks = 40

(* B on a message only when the look before, a wait earlier, read a message
   too: a message still printing can have a menu right behind it ("Which PC
   should be accessed?", pokefirered pc.inc: message, waitmessage, then the
   list), and a B that lands as the list opens cancels it and turns the PC off
   (console B, 2026-11-25). As {!Pc_deposit} gives an overworld frame a second
   look. *)
let on_message o =
  if o.message_seen then Press (B, { o with message_seen = false })
  else Press (Wait, { o with message_seen = true })

let pc_top (l : Steps.look) =
  List.exists (fun t -> l.label = Some t) Steps.pc_list_tops

let move_next o (l : Steps.look) =
  let on = { o with booted = true; message_seen = false } in
  match (l.view.screen, l.view.cursor) with
  | Box_grid, _ -> Opened
  | Overworld, _ when o.chosen -> Opened
  | Overworld, _ when not o.booted -> Press (A, on)
  | Text, _ -> on_message { o with booted = true }
  | Pc_list, Some 0 when pc_top l -> Press (A, on)
  | Pc_list, Some _ -> Press (Up, on)
  | Storage_menu, Some c when c = move_row && l.label = Some move_label ->
      Press (A, { on with chosen = true })
  | Storage_menu, Some c when c < move_row -> Press (Down, on)
  | Storage_menu, Some _ -> Press (Up, on)
  | _ -> Press (Wait, on)

let withdraw_next o l =
  let on = { o with booted = true; message_seen = false } in
  match (l.pc.view.screen, l.pc.view.cursor) with
  | _ when l.item_list -> Opened
  | Overworld, _ when not o.booted -> Press (A, on)
  | Pc_list, Some r when r = player_pc_row -> Press (A, on)
  | Pc_list, Some r when r < player_pc_row -> Press (Down, on)
  | Pc_list, Some _ -> Press (Up, on)
  | Text, _ when l.menu_top = Some item_storage -> Press (A, on)
  | Text, _ when l.menu_top = Some withdraw_item ->
      Press (A, { on with chosen = true })
  | Text, _ when not o.chosen -> on_message { o with booted = true }
  | _ -> Press (Wait, on)

let open_next target o l =
  match target with
  | Move_pokemon -> move_next o l.pc
  | Withdraw_item -> withdraw_next o l

let leave_next (l : Steps.look) : Steps.press option =
  match l.view.screen with
  | Overworld -> None
  | Other -> Some Wait
  | _ -> Some B

let pc_fail why = Menu_input.fail "pc_box" why

let target_name = function
  | Move_pokemon -> "the box screen"
  | Withdraw_item -> "WITHDRAW ITEM's list"

let rec open_from ~log steps target o looks =
  if looks = 0 then pc_fail (target_name target ^ " did not open")
  else
    let l = steps.look target in
    log ("PC: " ^ Pc_screen.screen_name l.pc.view.screen ^ ".");
    match open_next target o l with
    | Opened -> log ("PC: " ^ target_name target ^ ".")
    | Press (p, o) ->
        steps.press p;
        open_from ~log steps target o (looks - 1)

let open_menu ~log steps target = open_from ~log steps target opening max_looks
let to_box_screen ~log steps = open_menu ~log steps Move_pokemon

let rec leave_from ~log steps looks =
  if looks = 0 then pc_fail "the overworld did not come back"
  else
    match leave_next (steps.look Move_pokemon).pc with
    | None -> log "PC: back on the overworld."
    | Some p ->
        steps.press p;
        leave_from ~log steps (looks - 1)

let leave ~log steps =
  steps.press B;
  leave_from ~log steps max_looks

let menu_top () =
  match
    Text.Line_reading.read (Text_data.glyphs ())
      (Text.Item_pc_lines.menu_row 0)
      player_pc_menu_tops
  with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let item_list_shown () =
  match Effects.read () with
  | Some m -> Item_pc_screen.shown m = Some true
  | None -> false

let look target =
  let pc = Pc_deposit.look () in
  match target with
  | Move_pokemon -> { pc; menu_top = None; item_list = false }
  | Withdraw_item ->
      {
        pc;
        menu_top = (if pc.view.screen = Text then menu_top () else None);
        item_list = item_list_shown ();
      }

let screen_game_steps = { look; press = Pc_deposit.press }
