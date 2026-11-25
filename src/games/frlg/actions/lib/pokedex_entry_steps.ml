open Frlg_readers
module M = Menu_input
module Text = Frlg_text

let open_timeout_ms = 5000
let settle_ms = 300
let look_timeout_ms = 3000
let reread_ms = 100
let number_digits = 3
let pause ms = ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ])

let open_list () =
  Menu_cursor.open_start_menu ();
  match Start_menu_names.row_of "POKéDEX" (Start_menu_names.read_rows ()) with
  | None ->
      M.close "the Start menu" Start_menu.start_menu_open;
      M.fail ~repeats:true "no_pokedex" "no POKéDEX row on the Start menu"
  | Some row ->
      Menu_cursor.choose ~code:"no_start_menu" Menu_cursor.start_menu row
        ~taken:Menu_cursor.start_menu_taken;
      ignore
        (M.await_screen ~timeout_ms:open_timeout_ms ~code:"no_pokedex"
           "the Pokedex's contents" Pokedex_list.contents_shown);
      pause settle_ms;
      M.press Wire.A;
      ignore
        (M.await_screen ~code:"no_pokedex" "the Pokedex's numerical list"
           Pokedex_list.list_shown)

let number_on row =
  Text.Number_reading.read_left_aligned
    ~max_score:Text.Number_reading.small_max_score
    (Text_data.small_glyphs ())
    (Text.Text_lines.pokedex_list_number_digit row)
    ~max_cells:number_digits

let look_once () : Pokedex_entry.shown option =
  match Option.bind (Effects.read ()) Pokedex_list.cursor_row with
  | None -> None
  | Some row ->
      Option.map (fun number -> { Pokedex_entry.row; number }) (number_on row)

(* Two reads that agree: a tap redraws the list, and a frame mid-redraw must
   not stand as the look. *)
let rec look_until deadline previous =
  let now = look_once () in
  match (now, previous) with
  | Some s, Some p when s = p -> Some s
  | _ when Effects.now () > deadline -> None
  | _ ->
      pause reread_ms;
      look_until deadline now

let look () = look_until (Effects.now () +. float look_timeout_ms) None

let entry_on ~row ~name : Pokedex_entry.entry option =
  let line = Text.Text_lines.pokedex_list_name row in
  match Text.Line_reading.read (Text_data.glyphs ()) line [ name; "-----" ] with
  | Read { text = "-----"; _ } -> Some Not_seen
  | Read _ -> (
      match Effects.read () with
      | Some m when Pokedex_list.caught m row -> Some Caught
      | _ -> Some Seen)
  | No_match _ -> None

let close_list ~log () =
  M.press Wire.B;
  ignore
    (M.await_screen ~code:"not_closed" "the Pokedex's contents"
       Pokedex_list.contents_shown);
  pause settle_ms;
  M.press Wire.B;
  M.await_fade_in ~code:"not_closed" "the overworld after the Pokedex";
  ignore
    (M.await_screen ~code:"not_closed" "the Start menu after the Pokedex"
       Start_menu.start_menu_open);
  M.close "the Start menu" Start_menu.start_menu_open;
  M.settle_back ~label:"pokedex" ~log

let make ~log : Pokedex_entry.game_steps =
  {
    open_list;
    look;
    tap = (fun button -> M.taps button 1);
    entry_on;
    close_list = close_list ~log;
    log;
  }

let failure code detail = Pokemon_engine.Failure.cause ~repeats:true code detail

let read_number ~log ~number ~name =
  let read () =
    Effects.with_probes Pokedex_list.probes (fun () ->
        Pokedex_entry.read_with (make ~log) ~number ~name)
  in
  Result.bind (Menu_step.result read)
    (Result.map_error (failure "pokedex_unread"))

let read ~log slug =
  let species = Text_data.species_names () in
  match (Pokedex_entry.number_of species slug, List.assoc_opt slug species) with
  | Some number, Some name -> read_number ~log ~number ~name
  | _ ->
      Error
        (failure "not_in_kanto_pokedex" (slug ^ " is no Kanto Pokedex species"))
