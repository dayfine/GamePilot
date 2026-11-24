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
        Case_table.name = Printf.sprintf "%s pc screen: %s" backend image;
        input = (fun () -> tag (Pc_screen.read (measurements probes)));
        expectation = String.concat "-" (tags image);
      })
    images

let () =
  Case_table.run "pc readers"
    (List.concat_map
       (fun backend ->
         cases backend
           (Wire.read_image_probes ("fixtures/pc." ^ backend ^ ".probes.jsonl")))
       [ "switch"; "mgba" ])
