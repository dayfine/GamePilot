(* The naming screen's reader (Naming_screen) on native mGBA frames of BOX
   NAME? (Route 4 Pokémon Center's PC, 2026-11-25): the cursor on keys of each
   page at the red end of its cycle, three frames at its pink or white end
   (no key reads: the typer awaits the red), and box
   screens that are no naming screen, two with the box title's menu
   (Pc_box_screen.title_menu_row: JUMP, NAME). The fixtures are probe_images output
   (regen_fixtures.sh naming, from naming.mgba.map); the shifted fixture holds
   every frame at brightness x0.9 and x1.1, each channel +-12 and in grey 10
   levels (dev/reader_fixtures/shift_frame.py), and each must read the same.

   Headroom on these frames and their shifted versions (threshold; worst
   reading on the thing; worst off it), printed by this test:
   - page patch share of the page's colour: 0.8; 1.0; 0 (the other pages);
   - entry patch share of white: 0.9; 1.0; 0.70 (the box menu, brighter);
   - cursor edge share of cursor red: 0.3; 0.73; 0;
   - title menu arrow, dark share (Cursor_column): 0.10; 0.25; 0. *)

open Frlg_readers

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let page_name = function
  | Naming_screen.Upper -> "upper"
  | Lower -> "lower"
  | Others -> "others"

let menu_row m =
  match Pc_box_screen.title_menu_row m with
  | Some r -> Printf.sprintf "no page, menu row %d" r
  | None -> "no page"

let read m =
  match Naming_screen.page m with
  | None -> menu_row m
  | Some p -> (
      page_name p
      ^
      match Naming_screen.key p m with
      | Some k -> Printf.sprintf " r%dc%d" k.row k.col
      | None -> " no key")

(* The key frames' names say what they show: key_<page>_r<row>c<col>. *)
let expected image =
  match String.split_on_char '_' image with
  | [ "key"; page; _; ("white" | "pink") ] -> page ^ " no key"
  | "key" :: page :: key :: _ -> page ^ " " ^ key
  | [ "box1"; "title"; "menu" ] -> "no page, menu row 0"
  | [ "box1"; "title"; "menu"; "name" ] -> "no page, menu row 2"
  | _ -> "no page"

let base image = Filename.remove_extension (Filename.basename image)

let cases label images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s: %s" label image;
        input = (fun () -> read (measurements probes));
        expectation = expected (base image);
      })
    images

let menu_arrow_row image =
  match image with
  | "box1_title_menu" -> Some 0
  | "box1_title_menu_name" -> Some 2
  | _ -> None

(* The worst share on and off the thing each probe looks for: [pick image id]
   says whether the probe is on it, [None] for a probe the reader does not
   read on that image (the other layout's cursor boxes). The box screens'
   Forest fills the page patch with the others page's green: the entry's
   white rules them out. *)
let headroom images =
  let shares prefix pick =
    List.concat_map
      (fun (image, probes) ->
        List.filter_map
          (fun (id, _) ->
            if String.starts_with ~prefix id then
              match
                ( pick (base image) id,
                  Color_count.share (measurements probes) id )
              with
              | Some on, Some s -> Some (on, s)
              | _ -> None
            else None)
          probes)
      images
  in
  let worst l on =
    List.fold_left
      (fun (lo, hi) (is_on, s) ->
        if is_on = on then (min lo s, max hi s) else (lo, hi))
      (1., 0.) l
  in
  let report what l =
    let on_lo, _ = worst l true and _, off_hi = worst l false in
    Printf.printf "headroom %s: worst on %.2f, worst off %.2f\n" what on_lo
      off_hi
  in
  report "page"
    (shares "naming.page." (fun image id ->
         match String.split_on_char '_' image with
         | "key" :: page :: _ -> Some (id = "naming.page." ^ page)
         | _ -> None));
  report "entry white"
    (shares "naming.entry_white" (fun image _ ->
         Some (String.starts_with ~prefix:"key_" image)));
  report "cursor"
    (shares "naming.cursor." (fun image id ->
         match String.split_on_char '_' image with
         | [ "key"; page; key; phase ] ->
             let layout = if page = "others" then "others" else "letters" in
             let mine = "naming.cursor." ^ layout ^ "." in
             if not (String.starts_with ~prefix:mine id) then None
             else Some (phase <> "white" && phase <> "pink" && id = mine ^ key)
         | _ -> None));
  report "title menu arrow"
    (shares "pc_box.title_menu.row" (fun image id ->
         if not (String.starts_with ~prefix:"box1_" image) then None
         else
           Some
             (match menu_arrow_row image with
             | Some r -> id = Printf.sprintf "pc_box.title_menu.row%d" r
             | None -> false)))

let () =
  let frames = Wire.read_image_probes "fixtures/naming.mgba.probes.jsonl"
  and shifted =
    Wire.read_image_probes "fixtures/naming.mgba.shifted.probes.jsonl"
  in
  headroom (frames @ shifted);
  Table_test.run "naming readers"
    (cases "mgba" frames @ cases "mgba shifted" shifted)
