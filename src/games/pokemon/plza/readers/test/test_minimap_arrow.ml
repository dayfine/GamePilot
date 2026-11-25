open Plza_readers

let text = function Some a -> Printf.sprintf "%.0f" a | None -> "none"

(* A dart drawn in a 60 x 67 mask: tip, right wing, notch, left wing, turned
   [deg] clockwise about (30, 33). *)
let dart deg =
  let r = deg *. Float.pi /. 180. in
  let turn (x, y) =
    let x = x -. 30. and y = y -. 33. in
    ( 30. +. (x *. Float.cos r) -. (y *. Float.sin r),
      33. +. (x *. Float.sin r) +. (y *. Float.cos r) )
  in
  let poly = List.map turn [ (30., 14.); (45., 45.); (30., 35.); (15., 45.) ] in
  let inside (px, py) =
    let n = List.length poly in
    let edge i =
      let x1, y1 = List.nth poly i and x2, y2 = List.nth poly ((i + 1) mod n) in
      if
        y1 > py <> (y2 > py)
        && px < x1 +. ((py -. y1) /. (y2 -. y1) *. (x2 -. x1))
      then 1
      else 0
    in
    List.fold_left ( + ) 0 (List.init n edge) mod 2 = 1
  in
  Array.init 67 (fun y ->
      Array.init 60 (fun x ->
          inside (float_of_int x +. 0.5, float_of_int y +. 0.5)))

let synthetic (deg, expectation) : Table_test.case =
  {
    name = Printf.sprintf "a dart drawn at %.0f" deg;
    input = (fun () -> text (Minimap_arrow.mask_of_rows (dart deg)));
    expectation;
  }

let frame (name, expectation) : Table_test.case =
  {
    name;
    input = (fun () -> text (Minimap_arrow.read (Fixture_frames.frame name)));
    expectation;
  }

(* Degrees apart, either way round. *)
let apart a b = Float.abs (Float.rem (a -. b +. 540.) 360. -. 180.)

(* The fork's test tolerance. *)
let tolerance = 10.

(* A shifted frame never reads a wrong bearing: within 10 degrees of the frame,
   or none. A miss is allowed: the fork's HSV bounds (saturation and value 200
   and over) are as tight, and a greyed or reddened arrow falls out of them. *)
let shifted_cases =
  List.map
    (fun (path, probes) : Table_test.case ->
      let shift, name = Fixture_frames.shift_and_frame path in
      let read m = Minimap_arrow.read m in
      {
        name = Printf.sprintf "%s, %s: no wrong bearing" name shift;
        input =
          (fun () ->
            match
              ( read (Fixture_frames.measurements probes),
                read (Fixture_frames.frame name) )
            with
            | Some a, Some b ->
                if apart a b <= tolerance then "ok" else text (Some a)
            | None, _ -> "ok"
            | a, None -> text a);
        expectation = "ok";
      })
    Fixture_frames.shifted

let darts =
  [ (0., "358"); (90., "92"); (147., "146"); (238., "239"); (300., "299") ]

(* Every fixture frame: a bearing where the minimap shows, none elsewhere. *)
let frames =
  [
    ("alert-eye/en-0307-after-catch-143-360p", "none");
    ("alert-eye/en-0307-bunnelby-battle-113-360p", "none");
    ("alert-eye/lab-beldum-alpha-alert-true", "229");
    ("alert-eye/zone-15-gourgeist-alert-true", "132");
    ("alert-eye/zone-17-chespin-alert-true", "32");
    ("alert-eye/zone-20-dedenne-alakazam-alert-true", "259");
    ("alert-eye/zone-6-1-false", "10");
    ("alert-eye/zone-6-2-false", "14");
    ("alert-eye/zone-6-big-eye-1-true", "13");
    ("alert-eye/zone-6-houndour-1-true", "15");
    ("alert-eye/zone-6-initial-eye-1-true", "14");
    ("alert-eye/zone-6-translucent-1-true", "15");
    ("arrival-past-mission-banner/0008-white-fade", "none");
    ("arrival-past-mission-banner/0015-text-box", "none");
    ("arrival-past-mission-banner/0185-mission-banner", "none");
    ("arrival-past-mission-banner/0197-autosave-badge", "none");
    ("arrival-past-mission-banner/0210-controls-hint", "none");
    ("arrival-to-ad-subtitles/0044-text-box-advance-arrow", "none");
    ("arrival-to-ad-subtitles/0100-subtitles-advance-arrow", "none");
    ("arrival-to-ad/0001-platform-controls-hint", "none");
    ("arrival-to-ad/0007-plaza", "none");
    ("arrival-to-ad/0013-text-box", "none");
    ("arrival-to-ad/0033-autosave-badge", "none");
    ("arrival-to-ad/0038-light-pavement", "none");
    ("arrival-to-ad/0040-text-box-advance-arrow", "none");
    ("arrival-to-ad/0065-text-box-choice-box", "none");
    ("arrival-to-ad/0082-black-fade", "none");
    ("arrival-to-mission-banner/0173-text-box-choice-box", "none");
    ("battle-hud/de-0302b-battle-archway-no-hint", "none");
    ("battle-hud/de-0302b-battle-frame1-no-hint", "none");
    ("battle-hud/es-0302b-tepig-battle-low-hp", "none");
    ("battle-hud/es-0302b-tepig-battle-start", "none");
    ("battle-hud/it-0302b-battle-no-lock-on", "none");
    ("battle-hud/it-0308-zone1-road-no-battle", "294");
    ("battle-hud/it-0308b-zone-pillar-no-battle", "263");
    ("battle-hud/it-0308b-zone-pillar-wild-battle", "262");
    ("battle-hud/it-0309-lab-gate-ryon-dialog", "none");
    ("confirm-choices/English_0", "none");
    ("confirm-choices/English_1", "none");
    ("confirm-choices/English_2", "none");
    ("confirm-choices/German_2", "none");
    ("confirm-choices/Japanese_1", "none");
    ("dialog-boxes/mac-cannot-fast-travel-blue-box", "none");
    ("dialog-boxes/mac-restaurant-white-box", "none");
    ("dialog-choices/it-0102-villy-2-rows", "none");
    ("interact-prompt/arrival-past-banner-0003-prompt-hint", "none");
    ("interact-prompt/arrival-subtitles-0005-prompt-hint", "none");
    ("interact-prompt/arrival-to-ad-0005-prompt", "none");
    ("interact-prompt/mission-complete-0001-prompt", "none");
    ("interact-prompt/mission-complete-0003-nothing", "none");
    ("minimap/es-0303-start", "145");
    ("minimap/es-0306-start", "234");
    ("minimap/es-0307-start", "245");
    ("minimap/es-center-counter", "325");
    ("move-symbols/0303-andi-battle-no-zl-1", "none");
    ("move-symbols/0303-andi-battle-no-zl-3", "none");
    ("move-symbols/0303-andi-zl-held-1", "none");
    ("move-symbols/0303-andi-zl-held-3", "none");
    ("move-symbols/0303-andi-zl-held-target-4", "none");
    ("move-symbols/0303-andi-zl-held-target-5", "none");
    ("party-bar/0103-alley-party1", "none");
    ("party-bar/de-0205-elevator-prompt-steady", "none");
    ("party-bar/de-0205-lobby-start-party1", "none");
    ("party-bar/en-0302b-arch-collapsed-1080p", "144");
    ("party-bar/en-0302b-arch-collapsed-210", "none");
    ("party-bar/en-0302b-arch-map-card-138", "none");
    ("party-bar/en-0302b-arch-taunie-cutscene-150", "none");
    ("party-bar/en-0302b-arch-taunie-cutscene-153", "none");
    ("party-bar/en-0302b-arch-urbain-text-144", "none");
    ("party-bar/it-0102-parla-talk-prompt", "none");
    ("party-bar/party5-b", "258");
    ("party-bar/party5-slot0-selected", "282");
    ("party-bar/party5-slot0-sent-out", "343");
    ("party-bar/za2-m3v-s1-prompt", "none");
    ("tutorial-cards/it-0302b-map-missions-card", "none");
    ("tutorial-cards/it-menu-no-card", "none");
    ("synthetic/autosave-dim-glow-dark-wall", "none");
    ("synthetic/autosave-mint-banner-bands", "none");
    ("synthetic/autosave-stroke-green-sign-glow", "none");
    ("synthetic/autosave-stroke-no-glow", "none");
    ("synthetic/black", "none");
    ("synthetic/choice-1-row", "none");
    ("synthetic/choice-3-rows-middle", "none");
    ("synthetic/choice-3-rows-none", "none");
    ("synthetic/choice-3-rows-two", "none");
    ("synthetic/choice-3-short-rows-wide-bottom", "none");
    ("synthetic/moves-no-symbols", "none");
    ("synthetic/moves-normal-super-notvery-none", "none");
    ("synthetic/moves-super-none-normal-notvery", "none");
    ("synthetic/moves-two-blank", "none");
  ]

let () =
  Table_test.run "minimap_arrow"
    (List.map synthetic darts @ List.map frame frames @ shifted_cases)
