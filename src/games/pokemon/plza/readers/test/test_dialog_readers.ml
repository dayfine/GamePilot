(* The dialogue box and the advance chevron on the fork's test frames
   (PokemonLZA_DialogDetectors_Tests.cpp, PokemonLZA_Detectors_Tests.cpp and
   PokemonLZA_AutoStoryScreenEvents_Tests.cpp, CommandLineTests ee10083), and
   on each frame with its colours shifted (Fixture_frames.shifted_cases).

   The fork's frame with its arrow painted out is not drawn:
   0013, a box still typing its text, has the box without an arrow. The fork's
   empty image has no frame to probe.

   Headroom on these frames and their shifted versions:
   - white box edge (white: sum 500 up, stddev sum 20 at most, shares within
     0.08 of grey): the boxes sum 654-765 with stddev sums up to 11.1
     and shares within 0.018; the closest other edges are flat but dark (283)
     or bright but busy (stddev sum 38.5). A white fade reads as a box here;
     the screen's fade reading comes first (PokemonLZA_AutoStoryScreenEvents.cpp).
   - blue corner (shares within 0.25): the blue box's shares lie 0.05-0.17
     from the nearer blue, its stddev 0.
   - arrows (score under 120): the white arrow scores 19-65 on the blue box,
     the black arrow 21-78 on the white boxes.
   - advance chevron: see advance_arrow.ml (overlap 0.53 up against 0.51,
     strays 0.013 at most against 0.09). *)

open Plza_readers

let box_only m = Fixture_frames.yes_no (Dialog_box.shown ~white:Box_only m)

let box_and_arrow m =
  Fixture_frames.yes_no (Dialog_box.shown ~white:Box_and_arrow m)

let arrow m = Fixture_frames.yes_no (Advance_arrow.shown m)

let all m =
  Printf.sprintf "dialog %s (box only), %s (box and arrow), advance arrow %s"
    (box_only m) (box_and_arrow m) (arrow m)

let case read what frame expectation : Table_test.case =
  {
    name = Printf.sprintf "%s: %s" frame what;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let dialog_cases =
  [
    case box_and_arrow "a black frame, box and arrow" "synthetic/black" "no";
    case box_only "a black frame, box only" "synthetic/black" "no";
    case box_and_arrow "a white box, box and arrow"
      "dialog-boxes/mac-restaurant-white-box" "yes";
    case box_only "a white box, box only"
      "dialog-boxes/mac-restaurant-white-box" "yes";
    case box_only "a blue box" "dialog-boxes/mac-cannot-fast-travel-blue-box"
      "yes";
    case box_only "the tourist's yes or yes"
      "arrival-to-ad/0065-text-box-choice-box" "yes";
    case box_only "the bag's choice box"
      "arrival-to-mission-banner/0173-text-box-choice-box" "yes";
    case box_only "light pavement" "arrival-to-ad/0038-light-pavement" "no";
    case box_only "a plain dialog box"
      "arrival-past-mission-banner/0015-text-box" "yes";
    case box_only "a box still typing, box only" "arrival-to-ad/0013-text-box"
      "yes";
    case box_and_arrow "a box still typing, box and arrow"
      "arrival-to-ad/0013-text-box" "no";
  ]

(* arrival_to_ad: the arrow on 0040 only; arrival_to_ad_subtitles: 44, 49,
   53, 78 and 93-115; the other folders by "+advance_arrow" in the name. *)
let arrow_cases =
  List.map
    (fun (frame, expectation) -> case arrow "advance arrow" frame expectation)
    [
      ("arrival-to-ad/0001-platform-controls-hint", "no");
      ("arrival-to-ad/0007-plaza", "no");
      ("arrival-to-ad/0013-text-box", "no");
      ("arrival-to-ad/0033-autosave-badge", "no");
      ("arrival-to-ad/0038-light-pavement", "no");
      ("arrival-to-ad/0040-text-box-advance-arrow", "yes");
      ("arrival-to-ad/0065-text-box-choice-box", "no");
      ("arrival-to-ad/0082-black-fade", "no");
      ("arrival-to-ad-subtitles/0044-text-box-advance-arrow", "yes");
      ("arrival-to-ad-subtitles/0100-subtitles-advance-arrow", "yes");
      ("arrival-to-mission-banner/0173-text-box-choice-box", "no");
      ("arrival-past-mission-banner/0008-white-fade", "no");
      ("arrival-past-mission-banner/0015-text-box", "no");
      ("arrival-past-mission-banner/0185-mission-banner", "no");
      ("arrival-past-mission-banner/0197-autosave-badge", "no");
      ("arrival-past-mission-banner/0210-controls-hint", "no");
    ]

let () =
  Table_test.run "plza dialog readers"
    (dialog_cases @ arrow_cases @ Fixture_frames.shifted_cases all)
