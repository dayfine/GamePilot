open Frlg_readers
module M = Menu_input
module Text = Frlg_text

type rename = { from : string; to_ : string }

type game_steps = {
  open_move_pokemon : unit -> unit;
  read_title : string list -> string option;
  read_menu_label : int -> string option;
  read_menu_row : unit -> int option;
  await_naming_screen : unit -> bool;
  type_name : string -> unit;
  await_box_screen : unit -> bool;
  press : Wire.button -> unit;
  close : unit -> unit;
}

let name_row = 2

(* The title menu's rows: window at (140, 49), text from x 152, rows 16
   apart (mGBA, 2026-11-25). *)
let menu_left = 152
let menu_first_top = 58
let menu_pitch = 16
let menu_width = 76

let menu_line i : Text.Text_lines.t =
  {
    id = Printf.sprintf "pc_box_menu.%d" i;
    left = menu_left;
    indent = 2;
    glyph_top = menu_first_top + (menu_pitch * i);
    width = menu_width;
  }

let menu_labels = [ "JUMP"; "WALLPAPER"; "NAME"; "CANCEL" ]
let max_moves = 4

let rec to_name_row steps tries =
  match steps.read_menu_row () with
  | Some r when r = name_row -> ()
  | _ when tries = 0 -> M.fail "box_menu_cursor" "the arrow did not reach NAME"
  | Some r ->
      List.iter steps.press
        (List.init
           (abs (name_row - r))
           (fun _ -> if r < name_row then Wire.Down else Wire.Up));
      to_name_row steps (tries - 1)
  | None ->
      steps.press Wire.Down;
      to_name_row steps (tries - 1)

let quoted s = "\"" ^ s ^ "\""

let rename_shown steps ~log r =
  steps.press Wire.Up;
  steps.press Wire.A;
  if steps.read_menu_label name_row <> Some "NAME" then
    M.fail "box_menu_missing" "no NAME on the menu A opened on the box title";
  to_name_row steps max_moves;
  steps.press Wire.A;
  if not (steps.await_naming_screen ()) then
    M.fail "naming_no_screen" "NAME did not open the naming screen";
  steps.type_name r.to_;
  if not (steps.await_box_screen ()) then
    M.fail "box_name_wrong" "no box screen after the naming screen";
  match steps.read_title [ r.to_; r.from ] with
  | Some t when t = r.to_ -> log ("Box renamed " ^ quoted r.to_ ^ ".")
  | Some t -> M.fail "box_name_wrong" ("the title still reads " ^ quoted t)
  | None -> M.fail "box_name_wrong" ("the title does not read " ^ quoted r.to_)

let run steps ~log r =
  steps.open_move_pokemon ();
  (match steps.read_title [ r.from; r.to_ ] with
  | Some t when t = r.to_ && t <> r.from ->
      log ("The box is " ^ quoted r.to_ ^ " already.")
  | Some _ -> rename_shown steps ~log r
  | None ->
      M.fail "box_name_not_from"
        (Printf.sprintf "the box title reads neither %s nor %s" (quoted r.from)
           (quoted r.to_)));
  steps.close ()

(* The game's steps. Presses and waits measured on mGBA (2026-11-25). *)
let hold_ms = 100
let menu_ms = 500
let screen_ms = 1500
let look_timeout_ms = 1000
let screen_timeout_ms = 4000

let press_wait ms b =
  ignore (Effects.submit [ M.hold ~hold_ms ~cooldown_ms:ms b ])

let wait ms = ignore (Effects.await ~timeout_ms:ms (fun _ -> false))

let press b =
  match b with Wire.A -> press_wait screen_ms b | _ -> press_wait menu_ms b

let label line candidates =
  match Text.Line_reading.read (Text_data.glyphs ()) line candidates with
  | Read { text; _ } -> Some text
  | No_match _ -> None

(* The walk to the box screen and back out is Pc_box's, on Pc_screen's
   probes. *)
let open_move_pokemon ~log () =
  Effects.with_probes Pc_screen.probes (fun () ->
      Pc_box.to_box_screen ~log Pc_box.screen_game_steps)

let await_screen ~probes ok =
  Effects.with_probes probes (fun () ->
      match Effects.await ~timeout_ms:screen_timeout_ms ok with
      | Holds _ -> true
      | Timeout -> false)

(* The title slides in with the box screen: read until it reads. *)
let rec read_title_after tries candidates =
  match Text.Box_title.read (Text_data.glyphs ()) candidates with
  | Ok (Read { text; _ }) -> Some text
  | (Ok (No_match _) | Error _) when tries > 0 ->
      wait menu_ms;
      read_title_after (tries - 1) candidates
  | Ok (No_match _) | Error _ -> None

let title_reads = 4

let read_menu_row () =
  Effects.with_probes Pc_box_screen.probes (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms (fun _ -> true) with
      | Holds m -> Pc_box_screen.title_menu_row m
      | Timeout -> None)

let close ~log () =
  Effects.with_probes Pc_screen.probes (fun () ->
      Pc_box.leave ~log Pc_box.screen_game_steps)

let await_naming_screen () =
  await_screen ~probes:Naming_screen.probes (fun m ->
      Naming_screen.page m = Some Upper)

let await_box_screen () =
  await_screen ~probes:Pc_screen.probes (fun m ->
      (Pc_screen.read m).screen = Box_grid)

let box_chars = Naming_entry.box_name_chars

let type_name ~log name =
  Naming_entry.type_text
    (Naming_entry.screen_game_steps ~max_chars:box_chars)
    ~log ~max_chars:box_chars name

let screen_game_steps ~log =
  {
    open_move_pokemon = open_move_pokemon ~log;
    read_title = read_title_after title_reads;
    read_menu_label = (fun i -> label (menu_line i) menu_labels);
    read_menu_row;
    await_naming_screen;
    type_name = type_name ~log;
    await_box_screen;
    press;
    close = close ~log;
  }

let string_field name fields =
  match List.assoc_opt name fields with Some (`String s) -> Some s | _ -> None

let decode (fields : Json_field.obj) =
  match (string_field "from" fields, string_field "to" fields) with
  | Some from, Some to_ -> Ok { from; to_ }
  | _ ->
      Error
        (Pokemon_engine.Failure.cause ~repeats:true "bad_args"
           "rename_box takes \"from\" and \"to\"")

let rename_box ~log (_ : Pokemon_engine.Plan.event) args =
  Result.bind (decode args) (fun r ->
      M.run (fun () -> run (screen_game_steps ~log) ~log r))

let handlers ~log = [ ("rename_box", rename_box ~log) ]
