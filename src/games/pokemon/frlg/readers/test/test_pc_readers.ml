(* The PC reader (Pc_screen) on real screenshots: the fork's Switch captures
   (CommandLineTests PokemonFRLG/PcScreenReader, console B 2026-11-02) and
   native mGBA frames of a deposit at Lavender's Pokémon Center. The fixtures
   are the daemon's [probe_images] output: run [regen_fixtures.sh pc], which
   reads pc.switch.map and pc.mgba.map. Each image's name carries what it shows
   after "__", dash-separated: the screen (overworld, text, pclist,
   storagemenu, partypanel, boxgrid, monmenu, boxchooser, yesno, other), then
   cursorN when the cursor reads as row N. *)

open Frlg_readers

let tags image =
  let base = Filename.remove_extension (Filename.basename image) in
  match String.split_on_char '_' base |> List.rev with
  | last :: "" :: _ -> String.split_on_char '-' last
  | _ -> failwith ("no tags in " ^ image)

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let screen_tag : Pc_screen.screen -> string = function
  | Overworld -> "overworld"
  | Text -> "text"
  | Pc_list -> "pclist"
  | Storage_menu -> "storagemenu"
  | Party_panel -> "partypanel"
  | Box_grid -> "boxgrid"
  | Mon_menu -> "monmenu"
  | Box_chooser -> "boxchooser"
  | Yes_no -> "yesno"
  | Other -> "other"

let tag (v : Pc_screen.view) =
  String.concat "-"
    (screen_tag v.screen
    :: Option.fold ~none:[]
         ~some:(fun c -> [ "cursor" ^ string_of_int c ])
         v.cursor)

let cases backend images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s pc screen: %s" backend image;
        input = (fun () -> tag (Pc_screen.read (measurements probes)));
        expectation = String.concat "-" (tags image);
      })
    images

let stats id mean stddev = (id, Wire.Color_stats { mean; stddev })
let rgb r g b : Wire.rgb = { r; g; b }

(* Switch capture of "Deposit in which BOX?" with an 8-character box name
   ("xFUnDRRn", 2026-11-27): the relocated pc.chooser patch sits in the yellow
   margin above the name's glyphs (y 69..75) and reads flat yellow instead of
   overlapping the text and falling through to Box_grid. *)
let switch_long_name_chooser_probes =
  [
    stats "pc.game" (rgb 156.82 174.32 162.78) (rgb 76.29 53.2 64.54);
    stats "pc.data_panel" (rgb 149.59 152.45 179.9) (rgb 16.24 16.08 15.63);
    stats "pc.mon_menu" (rgb 218.18 172.47 109.71) (rgb 17.98 19.27 19.55);
    stats "pc.yes_no" (rgb 209.82 167.12 109.07) (rgb 30.81 20.78 14.13);
    stats "pc.chooser" (rgb 255. 226. 97.) (rgb 0. 0. 0.);
    stats "pc.party_panel" (rgb 141.01 183.18 127.94) (rgb 92.34 42.67 42.15);
  ]

(* Box_grid on Desert wallpaper (no popup): pc.chooser is tan with pattern
   stddev > 30, so it must still classify as Box_grid. *)
let desert_box_grid_probes =
  [
    stats "pc.game" (rgb 156.82 174.32 162.78) (rgb 76.29 53.2 64.54);
    stats "pc.data_panel" (rgb 149.59 152.45 179.9) (rgb 16.24 16.08 15.63);
    stats "pc.mon_menu" (rgb 218.18 172.47 109.71) (rgb 17.98 19.27 19.55);
    stats "pc.yes_no" (rgb 209.82 167.12 109.07) (rgb 30.81 20.78 14.13);
    stats "pc.chooser" (rgb 218.18 172.47 109.71) (rgb 17.98 19.27 19.55);
    stats "pc.party_panel" (rgb 218.18 172.47 109.71) (rgb 17.98 19.27 19.55);
  ]

let chooser_above_box_name () =
  match
    List.find_opt
      (fun (p : Wire.probe_spec) -> p.id = "pc.chooser")
      Pc_screen.probes
  with
  | Some { box; _ } ->
      let bottom_gba_y = (box.y +. box.h) *. Game_pixels.height in
      if bottom_gba_y <= 76. then "above-name"
      else Printf.sprintf "overlaps-name (bottom=%.1f)" bottom_gba_y
  | None -> "missing"

let extra_cases : Table_test.case list =
  [
    {
      name = "pc.chooser sits strictly above box name glyphs (y <= 76)";
      input = chooser_above_box_name;
      expectation = "above-name";
    };
    {
      name = "switch Deposit in which BOX? with 8-char box name -> boxchooser";
      input =
        (fun () ->
          tag (Pc_screen.read (measurements switch_long_name_chooser_probes)));
      expectation = "boxchooser";
    };
    {
      name = "desert wallpaper box grid -> boxgrid (not boxchooser)";
      input =
        (fun () -> tag (Pc_screen.read (measurements desert_box_grid_probes)));
      expectation = "boxgrid";
    };
  ]

let () =
  Table_test.run "pc readers"
    (List.concat_map
       (fun backend ->
         cases backend
           (Wire.read_image_probes ("fixtures/pc." ^ backend ^ ".probes.jsonl")))
       [ "switch"; "mgba" ]
    @ extra_cases)
