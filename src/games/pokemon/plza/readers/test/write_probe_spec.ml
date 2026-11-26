(* Prints the [subscribe] params of every PLZA reader's probes on the native
   viewport, for the daemon's offline [probe_images] tool (regen_fixture.sh),
   each blob template named by its file in assets/templates, which the script
   copies beside the spec. With [--no-minimap], the minimap's 148 cells are
   left out: the shifted fixture (nine shifts of every frame) stays under
   GitHub's 50 MB warning without them, and the minimap scales each channel to
   its reference before comparing, which a colour shift mostly cancels.

   With [--second FIXTURE DIR], it writes instead, for each frame of the
   fixture, DIR/<folder>/<frame>.json (DIR/<shift>/<folder>/<frame>.json for
   a shifted frame): the probes a two-frame read subscribes
   from what that frame shows, the party bars' made from its cards
   ({!Plza_readers.Party_slots.bar_probes}) and the caught mark's from its
   plate's bar ({!Plza_readers.Lock_plate.mark_probes}).

   With [--gifts LANGUAGE], only the Mystery Gift steps' readers' probes
   ({!Plza_readers.Main_menu_row}, {!Plza_readers.Mystery_gift_screen}, the
   Boxes' and their cell's, the SAVE dialog's), the gift's name matched by its
   template in that language (gift-name-vivillon-<language>.png, copied beside
   the spec): en for fixtures/gifts/gifts.probes.jsonl, fr for
   fixtures/gifts/gifts.fr.probes.jsonl. *)

let native : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }
let no_minimap = Array.mem "--no-minimap" Sys.argv

let kept (p : Wire.probe_spec) =
  not (no_minimap && String.starts_with ~prefix:"minimap." p.id)

let params probes =
  let request =
    Wire.json_of_message (Request { id = 1; call = Subscribe probes })
  in
  Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request)

let second_probes m =
  let open Plza_readers in
  Option.fold ~none:[]
    ~some:(Party_slots.bar_probes ~picture:native)
    (Party_slots.cards m)
  @ Option.fold ~none:[]
      ~some:(Lock_plate.mark_probes ~picture:native)
      (Lock_plate.bar m)

let write_second_spec dir (path, probes) =
  match second_probes { seq = 1; t_ms = 0.; probes } with
  | [] -> ()
  | second ->
      let out =
        Filename.concat dir (Filename.remove_extension path ^ ".json")
      in
      let rec make_folder folder =
        if not (Sys.file_exists folder) then (
          make_folder (Filename.dirname folder);
          (* "DIR/." exists once DIR does. *)
          if not (Sys.file_exists folder) then Sys.mkdir folder 0o755)
      in
      make_folder (Filename.dirname out);
      Out_channel.with_open_text out (fun oc ->
          output_string oc (params second))

let () =
  match Array.to_list Sys.argv with
  | [ _; "--second"; fixture; dir ] ->
      List.iter (write_second_spec dir) (Wire.read_image_probes fixture)
  | [ _; "--gifts"; language ] ->
      print_endline
        (params
           (Plza_readers.Main_menu_row.probes ~picture:native
              ~assets:Plza_readers.Blob_assets.file_names
           @ Plza_readers.Boxes_screen.probes ~picture:native
           @ Plza_readers.Box_cell.probes ~picture:native
           @ Plza_readers.Save_dialog.probes ~picture:native
           @ Plza_readers.Mystery_gift_screen.probes ~picture:native
               ~gift_name:
                 (Some (Printf.sprintf "gift-name-vivillon-%s.png" language))))
  | _ ->
      let assets = Plza_readers.Blob_assets.file_names in
      print_endline
        (params
           (List.filter kept
              (Plza_readers.Story_screen.probes ~picture:native ~assets
              @ Plza_readers.Confirm_choices.probes ~picture:native)))
