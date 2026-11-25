(* Prints the [subscribe] params of every PLZA reader's probes on the native
   viewport, for the daemon's offline [probe_images] tool (regen_fixture.sh),
   each blob template named by its file in assets/templates, which the script
   copies beside the spec. *)

let native : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let () =
  let assets = Plza_readers.Blob_assets.file_names in
  let call =
    Wire.Subscribe
      (Plza_readers.Story_screen.probes ~picture:native ~assets
      @ Plza_readers.Confirm_choices.probes ~picture:native)
  in
  let request = Wire.json_of_message (Request { id = 1; call }) in
  print_endline
    (Yojson.Safe.pretty_to_string (Yojson.Safe.Util.member "params" request))
