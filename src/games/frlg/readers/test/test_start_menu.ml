(* Start menu reader on the golden frame (open panel) and on overworld colors. *)

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let () =
  let frame mean stddev : Effects.measurements =
    {
      seq = 1;
      t_ms = 0.;
      probes =
        [
          (Frlg_readers.Start_menu.probe_id, Wire.Color_stats { mean; stddev });
        ];
    }
  in
  let rgb r g b : Wire.rgb = { r; g; b } in
  expect "reader: white flat panel is open"
    (Frlg_readers.Start_menu.start_menu_open
       (frame (rgb 248.1 248.0 247.9) (rgb 6.2 6.1 6.3)));
  expect "reader: red roof is closed"
    (not
       (Frlg_readers.Start_menu.start_menu_open
          (frame (rgb 176.4 96.2 88.9) (rgb 48.3 41.7 39.5))));
  expect "reader: white but busy (text) is closed"
    (not
       (Frlg_readers.Start_menu.start_menu_open
          (frame (rgb 230. 230. 230.) (rgb 60. 60. 60.))));
  expect "reader: missing probe is closed"
    (not
       (Frlg_readers.Start_menu.start_menu_open
          { seq = 1; t_ms = 0.; probes = [] }))
