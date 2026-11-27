module G = Screen_graph.Graph
module S = Plza_readers.Mystery_gift_screen
module R = Plza_readers.Main_menu_row
module K = Switch.Code_keyboard

type answer = S.answer

type screen =
  | Main_menu of int
  | Gift_menu
  | Gift_list of int
  | Card
  | Stop_receiving of answer
  | Disconnect of answer
  | Message
  | Keyboard

let is_main_menu = function Main_menu _ -> true | _ -> false
let is_gift_list = function Gift_list _ -> true | _ -> false
let answer_text = function S.Yes -> "Yes" | S.No -> "No"

let show = function
  | Main_menu r -> Printf.sprintf "Main_menu(%d)" r
  | Gift_menu -> "Gift_menu"
  | Gift_list k -> Printf.sprintf "Gift_list(%d)" k
  | Card -> "Card"
  | Stop_receiving a -> Printf.sprintf "Stop_receiving(%s)" (answer_text a)
  | Disconnect a -> Printf.sprintf "Disconnect(%s)" (answer_text a)
  | Message -> "Message"
  | Keyboard -> "Keyboard"

let press ~hold_ms ~cooldown_ms button : Wire.command =
  Press
    {
      buttons = [ button ];
      left_stick = None;
      right_stick = None;
      hold_ms;
      cooldown_ms;
    }

let dpad_hold_ms = 80
let dpad_cooldown_ms = 300
let button_hold_ms = 100
let short_cooldown_ms = 1500
let menu_cooldown_ms = 2000
let confirm_cooldown_ms = 2500
let connect_cooldown_ms = 4000
let enter_cooldown_ms = 5000
let claim_cooldown_ms = 8000

let dpad button =
  press ~hold_ms:dpad_hold_ms ~cooldown_ms:dpad_cooldown_ms button

let a_2s = press ~hold_ms:button_hold_ms ~cooldown_ms:menu_cooldown_ms A
let a_2500 = press ~hold_ms:button_hold_ms ~cooldown_ms:confirm_cooldown_ms A
let b_1500 = press ~hold_ms:button_hold_ms ~cooldown_ms:short_cooldown_ms B
let claim_a = press ~hold_ms:button_hold_ms ~cooldown_ms:claim_cooldown_ms A
let plus_5s = press ~hold_ms:button_hold_ms ~cooldown_ms:enter_cooldown_ms Start

let to_internet =
  [
    press ~hold_ms:button_hold_ms ~cooldown_ms:short_cooldown_ms A;
    press ~hold_ms:button_hold_ms ~cooldown_ms:connect_cooldown_ms A;
  ]

(* Link Play has no reader yet (Screen-Graph.md decision 8). *)
let open_gifts_cmds = [ a_2s; dpad Right; dpad Right; dpad Down; a_2s ]
let link_play_row = 5
let hold_ms = 1000
let wait_ms = 2500
let cursor_wait_ms = 1500
let connect_wait_ms = 15_000
let claim_wait_ms = 20_000

let transit ?(arrive = G.Held hold_ms) ?(within_ms = wait_ms) input leads_to :
    screen G.edge =
  { input; leads_to; arrive; within_ms; kind = Transit }

let act ?(within_ms = wait_ms) name input leads_to : screen G.edge =
  { input; leads_to; arrive = Held hold_ms; within_ms; kind = Acts name }

let main_menu_edges r =
  let next = (r + 1) mod R.rows in
  let prev = (r + R.rows - 1) mod R.rows in
  let nav =
    [
      transit ~arrive:First_read ~within_ms:cursor_wait_ms
        [ dpad Down ]
        (Main_menu next);
      transit ~arrive:First_read ~within_ms:cursor_wait_ms
        [ dpad Up ]
        (Main_menu prev);
    ]
  in
  if r = link_play_row then transit open_gifts_cmds Gift_menu :: nav else nav

let gift_list_edges k =
  let next = (k + 1) mod S.items in
  let prev = (k + S.items - 1) mod S.items in
  [
    transit ~arrive:First_read ~within_ms:cursor_wait_ms
      [ dpad Down ]
      (Gift_list next);
    transit ~arrive:First_read ~within_ms:cursor_wait_ms
      [ dpad Up ]
      (Gift_list prev);
    transit [ b_1500 ] (Stop_receiving Yes);
    act ~within_ms:claim_wait_ms "claim" [ claim_a ] Card;
  ]

let edges = function
  | Main_menu r -> main_menu_edges r
  | Gift_menu ->
      [
        transit [ b_1500 ] (Disconnect Yes);
        act ~within_ms:connect_wait_ms "connect" to_internet (Gift_list 0);
        act "open_keyboard" [ dpad Down; a_2s ] Keyboard;
      ]
  | Gift_list k -> gift_list_edges k
  | Card -> [ transit [ b_1500 ] (Gift_list 0) ]
  | Stop_receiving Yes -> [ transit [ a_2500 ] Gift_menu ]
  | Stop_receiving No -> [ transit [ dpad Up ] (Stop_receiving Yes) ]
  | Disconnect Yes -> [ transit [ a_2500 ] Message ]
  | Disconnect No -> [ transit [ dpad Up ] (Disconnect Yes) ]
  | Message -> [ transit [ a_2500 ] (Main_menu link_play_row) ]
  | Keyboard ->
      [
        transit [ b_1500 ] Gift_menu;
        act ~within_ms:connect_wait_ms "enter" [ plus_5s ] (Gift_list 0);
      ]

let read_question m =
  match S.question m with
  | Some a when S.list_shown m -> [ Stop_receiving a ]
  | Some a -> [ Disconnect a ]
  | None -> []

let read_gift_screen m =
  if S.card m then [ Card ]
  else
    match read_question m with
    | _ :: _ as q -> q
    | [] when S.message m -> [ Message ]
    | [] when S.gift_menu m -> [ Gift_menu ]
    | [] when S.list_active m -> (
        match S.selected_item m with Some k -> [ Gift_list k ] | None -> [])
    | [] when K.shown m -> [ Keyboard ]
    | [] -> []

let read m =
  match R.highlighted m with
  | Some r -> [ Main_menu r ]
  | None -> read_gift_screen m

let screens =
  List.init R.rows (fun r -> Main_menu r)
  @ [ Gift_menu; Card; Message; Keyboard ]
  @ List.init S.items (fun k -> Gift_list k)
  @ [ Stop_receiving Yes; Stop_receiving No; Disconnect Yes; Disconnect No ]

let make probes : screen G.t =
  {
    name = "plza.gifts";
    probes;
    read;
    edges;
    screens;
    home = Main_menu link_play_row;
    when_unread = Press [ b_1500 ];
    show;
    describe = S.describe;
  }

let walk_graph = make []

let graph ~picture ~assets ~gift_name =
  make (R.probes ~picture ~assets @ S.probes ~picture ~gift_name @ K.probes)
