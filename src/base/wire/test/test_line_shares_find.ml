(* The v1.12 probe kinds, core.line_shares@1 and core.find@1: their goldens
   decode into the typed params and results, the constructors make the golden
   probes, refuse what the daemon refuses, and the total result readers give
   None, not an exception, on a result that is not theirs. *)

let rec protocol_dir dir =
  let candidate = Filename.concat (Filename.concat dir "protocol") "v1" in
  if Sys.file_exists candidate then candidate
  else protocol_dir (Filename.dirname dir)

let golden file =
  Wire.message_of_json
    (Yojson.Safe.from_file
       (Filename.concat (protocol_dir (Sys.getcwd ())) file))

let subscribed () =
  match golden "46-subscribe.line_shares_find.request.json" with
  | Wire.Request { call = Wire.Subscribe probes; _ } -> probes
  | _ -> []

let frame_probes () =
  match golden "47-frame.line_shares_find.notification.json" with
  | Wire.Notification (Wire.Frame { frame; _ }) -> frame.probes
  | _ -> []

let sky_blue =
  Wire.Line_shares.
    [
      greater ~r:0 ~g:0 ~b:1 200;
      greater ~r:0 ~g:1 ~b:0 160;
      greater ~r:(-1) ~g:0 ~b:1 60;
    ]

let glyph_box = { Wire.x = 0.497396; y = 0.813889; w = 0.004167; h = 0.006481 }
let arrow_box = { Wire.x = 0.713542; y = 0.861111; w = 0.057292; h = 0.111111 }
let shape = "9b0e51d07e9c3f0aa0de7d06e2b1b2c0a5d1f7e3c4b6a8d9e0f1a2b3c4d5e6f7"

let chevron_params () =
  Wire.Blob_find.params ~min_size:(26., 15.) ~max_size:(40., 24.) ~margin:4.
    ~shape
    ~filters:
      [
        { low = (235, 235, 220); high = (255, 255, 255) };
        { low = (0, 0, 0); high = (110, 110, 110) };
      ]
    ~min_area:1. ()

let probe_case name index make =
  {
    Table_test.name;
    input =
      (fun () ->
        match (List.nth_opt (subscribed ()) index, make ()) with
        | Some golden, Ok made -> string_of_bool (golden = made)
        | None, _ -> "no golden probe"
        | _, Error why -> why);
    expectation = "true";
  }

let refused name made =
  {
    Table_test.name;
    input = (fun () -> match made () with Ok _ -> "ok" | Error _ -> "refused");
    expectation = "refused";
  }

let filter = Wire.Blob_find.{ low = (0, 0, 0); high = (9, 9, 9) }
let find_params = Wire.Blob_find.params ~filters:[ filter ]

let constructor_cases =
  [
    probe_case "line shares constructor makes the golden probe" 0 (fun () ->
        Wire.line_shares_probe ~id:"controls_hint.glyph" ~box:glyph_box
          ~delivery:Every ~test:sky_blue);
    probe_case "find constructor makes the golden probe" 1 (fun () ->
        Result.map
          (Wire.find_probe ~id:"advance_arrow" ~box:arrow_box ~delivery:Every)
          (chevron_params ()));
    refused "an empty test" (fun () ->
        Wire.line_shares_probe ~id:"p" ~box:glyph_box ~delivery:Every ~test:[]);
    refused "no filter" (fun () ->
        Wire.Blob_find.params ~filters:[] ~min_area:1. ());
    refused "min_area below 1" (fun () -> find_params ~min_area:0.5 ());
    refused "min_area above max_area" (fun () ->
        find_params ~max_area:4. ~min_area:5. ());
    refused "a filter's low end above its high end" (fun () ->
        Wire.Blob_find.params
          ~filters:[ { low = (9, 0, 0); high = (8, 0, 0) } ]
          ~min_area:1. ());
    refused "a channel past 255" (fun () ->
        Wire.Blob_find.params
          ~filters:[ { low = (0, 0, 0); high = (256, 0, 0) } ]
          ~min_area:1. ());
    refused "a negative margin" (fun () ->
        find_params ~margin:(-1.) ~min_area:1. ());
    refused "a negative size" (fun () ->
        find_params ~min_size:(-1., 0.) ~min_area:1. ());
  ]

let result_of id = List.assoc_opt id (frame_probes ())

let shares_text (s : Wire.Line_shares.t) =
  String.concat " "
    (List.map (Printf.sprintf "%g") (s.rows @ [ -1. ] @ s.columns))

let blob_text (b : Wire.Blob_find.blob) =
  Printf.sprintf "%d %g,%g %gx%g fill %g stray %s overlap %s score %s" b.filter
    b.x b.y b.w b.h b.fill
    (Option.fold ~none:"-" ~some:string_of_float b.stray)
    (Option.fold ~none:"-" ~some:string_of_float b.overlap)
    (Option.fold ~none:"-" ~some:string_of_float b.score)

let read id reader text =
  match Option.bind (result_of id) reader with
  | Some value -> text value
  | None -> "none"

let blobs_text blobs = String.concat "; " (List.map blob_text blobs)

let result_cases =
  [
    {
      Table_test.name = "line shares from the golden frame";
      input =
        (fun () -> read "controls_hint.glyph" Wire.line_shares shares_text);
      expectation =
        "0.375 0.5 0.25 0.25 0.5 0.375 0.25 -1 0.142857 0.428571 0.571429 \
         0.428571 0.285714 0.428571 0.428571 0.142857";
    };
    {
      Table_test.name = "blobs from the golden frame";
      input = (fun () -> read "advance_arrow" Wire.blobs blobs_text);
      expectation =
        "1 1418,982 32x20 fill 0.359375 stray 0. overlap 0.585443 score -";
    };
    {
      Table_test.name = "no blobs";
      input = (fun () -> read "choice_arrow" Wire.blobs blobs_text);
      expectation = "";
    };
    {
      Table_test.name = "blobs of a line shares result: none";
      input = (fun () -> read "controls_hint.glyph" Wire.blobs blobs_text);
      expectation = "none";
    };
    {
      Table_test.name = "line shares of a colour stats result: none";
      input =
        (fun () ->
          match
            Wire.line_shares
              (Wire.Color_stats
                 {
                   mean = { r = 0.; g = 0.; b = 0. };
                   stddev = { r = 0.; g = 0.; b = 0. };
                 })
          with
          | Some _ -> "some"
          | None -> "none");
      expectation = "none";
    };
    {
      Table_test.name = "a blob missing its fill: none";
      input =
        (fun () ->
          match
            Wire.blobs
              (Wire.Other
                 (Yojson.Safe.from_string
                    {|{"kind":"core.find@1","blobs":[{"filter":0,"x":1,"y":1,"w":1,"h":1}]}|}))
          with
          | Some _ -> "some"
          | None -> "none");
      expectation = "none";
    };
    {
      Table_test.name = "made results read back";
      input =
        (fun () ->
          let shares =
            { Wire.Line_shares.rows = [ 0.5 ]; columns = [ 1.; 0. ] }
          in
          match
            ( Wire.line_shares (Wire.line_shares_result shares),
              Wire.blobs (Wire.find_result []) )
          with
          | Some s, Some [] -> shares_text s
          | _ -> "none");
      expectation = "0.5 -1 1 0";
    };
  ]

let pixel_cases =
  List.map
    (fun (pixel, expected) ->
      let r, g, b = pixel in
      {
        Table_test.name = Printf.sprintf "sky blue passes (%d, %d, %d)" r g b;
        input =
          (fun () -> string_of_bool (Wire.Line_shares.passes sky_blue pixel));
        expectation = string_of_bool expected;
      })
    [
      ((100, 200, 230), true);
      ((170, 200, 230), false) (* b only 60 over r *);
      ((100, 160, 230), false);
      ((100, 200, 200), false);
    ]

let () =
  Table_test.run "line shares and find"
    (constructor_cases @ result_cases @ pixel_cases)
