open Bdsp_readers
module EBR = Eye_blink_reader

let fail msg =
  prerr_endline ("FAIL: " ^ msg);
  exit 1

let assert_true label cond = if not cond then fail label

let assert_float_near label ~eps ~got ~want =
  if Float.abs (got -. want) > eps then fail label

let box_near ~eps (a : Wire.box) (b : Wire.box) =
  Float.abs (a.x -. b.x) <= eps
  && Float.abs (a.y -. b.y) <= eps
  && Float.abs (a.w -. b.w) <= eps
  && Float.abs (a.h -. b.h) <= eps

let probe_spec_near ~eps (got : Wire.probe_spec) (want : Wire.probe_spec) =
  { got with box = want.box } = want && box_near ~eps got.box want.box

let assert_probe_specs_near label ~eps ~got ~want =
  assert_true label
    (List.length got = List.length want
    && List.for_all2 (probe_spec_near ~eps) got want)

let full_pic : Wire.box = { x = 0.0; y = 0.0; w = 1.0; h = 1.0 }

let test_munchlax_probe_spec () =
  let hash = "abc123deadbeef" in
  let target = EBR.munchlax_target ~template:hash in
  let specs = EBR.probes ~picture:full_pic [ target ] in
  let want : Wire.probe_spec list =
    [
      {
        id = EBR.munchlax_probe_id;
        kind = "core.template_ncc@1";
        box = { x = 0.3828; y = 0.6306; w = 0.0208; h = 0.0481 };
        delivery = Wire.Every;
        template = Some hash;
        ink = None;
        skip_seams = false;
        color_range = None;
        test = [];
        find = None;
      };
    ]
  in
  assert_probe_specs_near "munchlax probe spec matches" ~eps:1e-6 ~got:specs
    ~want

let test_score_reading () =
  let frame : Wire.frame =
    {
      seq = 10;
      t_ms = 333.3;
      probes =
        [
          ( EBR.munchlax_probe_id,
            Wire.Template_ncc { score = 0.87; x = 0.39; y = 0.64 } );
          ( "other_probe",
            Wire.Color_stats
              {
                mean = { r = 10.0; g = 20.0; b = 30.0 };
                stddev = { r = 1.0; g = 1.0; b = 1.0 };
              } );
        ];
    }
  in
  (match EBR.score frame EBR.munchlax_probe_id with
  | Some v ->
      assert_float_near "reads template_ncc score" ~eps:1e-9 ~got:v ~want:0.87
  | None -> fail "expected Some score for munchlax probe");
  assert_true "ignores non-ncc probe" (EBR.score frame "other_probe" = None);
  assert_true "missing probe returns None" (EBR.score frame "missing" = None)

let test_dip_detection () =
  let resting = 0.90 in
  let threshold = 0.25 in
  assert_float_near "open eye depth is 0" ~eps:1e-9
    ~got:(EBR.dip_depth ~resting 0.92)
    ~want:0.0;
  assert_float_near "closed eye depth" ~eps:1e-9
    ~got:(EBR.dip_depth ~resting 0.45)
    ~want:0.5;
  assert_float_near "negative score clamps depth to 1" ~eps:1e-9
    ~got:(EBR.dip_depth ~resting (-0.20))
    ~want:1.0;
  assert_true "open eye is not a dip"
    (not (EBR.is_blink_dip ~resting ~threshold 0.85));
  assert_true "deep drop is a dip" (EBR.is_blink_dip ~resting ~threshold 0.45);
  assert_true "non-positive resting never dips"
    (not (EBR.is_blink_dip ~resting:0.0 ~threshold 0.0));
  assert_true "non-positive threshold never dips"
    (not (EBR.is_blink_dip ~resting ~threshold:0.0 0.45))

let () =
  test_munchlax_probe_spec ();
  test_score_reading ();
  test_dip_detection ();
  print_endline "OK"
