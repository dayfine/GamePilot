(* The controls hint, autosave badge, tutorial card, choice rows and arrow, and
   the whole story screen on the fork's test frames
   (PokemonLZA_Detectors_Tests.cpp, PokemonLZA_DialogDetectors_Tests.cpp,
   PokemonLZA_AutoStoryScreenEvents_Tests.cpp; CommandLineTests ee10083) and
   its synthetic frames (draw_synthetic_frames.py), and every frame with its
   colours shifted reading the same story screen (Fixture_frames).

   Left out: the fork's 720p language frames (the readers take 1080p frames,
   as the daemon's native viewport gives them) and its empty image.

   Headroom on these frames and their shifted versions (the limit in
   brackets):
   - controls hint: the hints' cards are 0.86 sky blue at least (0.80), their
     "?" 0.80 at most (0.90, the fork's 0.70), the strips around 0 (0.10).
     Other frames' cards reach 0.92 somewhere but fail on the "?" or strips.
   - autosave badge: at its best place each badge's icon is 0.14-0.21 white
     (0.08-0.40) and 0.28 dim cyan at least (0.25; the synthetic glow is
     0.30), the strips around 0.036 at most (0.05). Where an icon passes on a
     frame without a badge (0033), its strips are 0.26 at least.
   - tutorial card: the card's panel averages 216 a channel at least (200, the
     fork's 225), its edges 83 at most (100) with a stddev of 5.9 at most (12);
     brighter panels elsewhere have edges 109 up or a stddev 17 up.
   - choice rows: on the real menus highlighted strips average 230 a channel
     at least (200) with stddev sums under 1 (30), panel strips are 12 inside
     every panel-blue bound, rows' text bands 0.13 bright at least (0.005).
   - choice arrow: the arrows score 28-65 (80); other blobs of its shape 93
     up. 0173's arrow scores 98 and does not read; its rows do. *)

open Plza_readers

let read frame f () = f (Fixture_frames.frame frame)
let yes_no = Fixture_frames.yes_no

let case name frame f expectation : Table_test.case =
  {
    name = Printf.sprintf "%s: %s" frame name;
    input = read frame f;
    expectation;
  }

let hint m = yes_no (Controls_hint.shown m)
let autosave m = yes_no (Autosave_badge.shown m)
let arrival = "arrival-to-ad/"
let past = "arrival-past-mission-banner/"

(* The arrival to the ad: the hint up to frame 6, no autosave badge; the
   subtitles likewise; the other folders as their names say. *)
let story_cases =
  List.concat_map
    (fun (frame, has_hint, has_badge) ->
      [
        case "controls hint" frame hint has_hint;
        case "autosave badge" frame autosave has_badge;
      ])
    [
      (arrival ^ "0001-platform-controls-hint", "yes", "no");
      (arrival ^ "0007-plaza", "no", "no");
      (arrival ^ "0013-text-box", "no", "no");
      (arrival ^ "0033-autosave-badge", "no", "no");
      (arrival ^ "0038-light-pavement", "no", "no");
      (arrival ^ "0040-text-box-advance-arrow", "no", "no");
      (arrival ^ "0065-text-box-choice-box", "no", "no");
      (arrival ^ "0082-black-fade", "no", "no");
      ("arrival-to-ad-subtitles/0044-text-box-advance-arrow", "no", "no");
      ("arrival-to-ad-subtitles/0100-subtitles-advance-arrow", "no", "no");
      ("arrival-to-mission-banner/0173-text-box-choice-box", "no", "no");
      (past ^ "0008-white-fade", "no", "no");
      (past ^ "0015-text-box", "no", "no");
      (past ^ "0185-mission-banner", "no", "no");
      (past ^ "0197-autosave-badge", "no", "yes");
      (past ^ "0210-controls-hint", "yes", "no");
    ]

let synthetic_badge_cases =
  List.map
    (fun (frame, expectation) ->
      case "autosave badge" ("synthetic/" ^ frame) autosave expectation)
    [
      ("autosave-dim-glow-dark-wall", "yes");
      ("autosave-stroke-no-glow", "no");
      ("autosave-mint-banner-bands", "yes");
      ("autosave-stroke-green-sign-glow", "no");
    ]

let card_cases =
  [
    case "tutorial card" "tutorial-cards/it-0302b-map-missions-card"
      (fun m -> yes_no (Tutorial_card.shown m))
      "yes";
    case "tutorial card" "tutorial-cards/it-menu-no-card"
      (fun m -> yes_no (Tutorial_card.shown m))
      "no";
  ]

let rows m =
  match Choice_rows.read m with
  | Some r -> Printf.sprintf "row %d of %d" r.selected r.count
  | None -> "no choice menu"

let choice_arrow m = yes_no (Choice_arrow.shown m)

let choice_cases =
  List.map
    (fun (frame, expectation) -> case "choice rows" frame rows expectation)
    [
      ("synthetic/choice-3-rows-middle", "row 1 of 3");
      ("synthetic/choice-3-short-rows-wide-bottom", "row 2 of 3");
      ("synthetic/choice-1-row", "no choice menu");
      ("synthetic/choice-3-rows-none", "no choice menu");
      ("synthetic/choice-3-rows-two", "no choice menu");
      (arrival ^ "0065-text-box-choice-box", "row 0 of 2");
      ("arrival-to-mission-banner/0173-text-box-choice-box", "row 0 of 2");
      ("dialog-choices/it-0102-villy-2-rows", "row 0 of 2");
      (arrival ^ "0038-light-pavement", "no choice menu");
    ]
  @ [
      case "choice arrow"
        (arrival ^ "0065-text-box-choice-box")
        choice_arrow "yes";
      case "choice arrow" "dialog-choices/it-0102-villy-2-rows" choice_arrow
        "yes";
    ]

(* The fork's screen-events cases: dialog box, choice box, white fade. *)
let events m =
  let s = Story_screen.read m in
  Printf.sprintf "dialog %s, choice %s, white fade %s" (yes_no s.dialog_box)
    (yes_no s.choice_box)
    (yes_no (s.fade = White))

let screen_cases =
  List.map
    (fun (name, frame, expectation) -> case name frame events expectation)
    [
      ( "the tourist's yes or yes",
        arrival ^ "0065-text-box-choice-box",
        "dialog yes, choice yes, white fade no" );
      ( "the bag's choice box",
        "arrival-to-mission-banner/0173-text-box-choice-box",
        "dialog yes, choice yes, white fade no" );
      ( "the white fade",
        past ^ "0008-white-fade",
        "dialog no, choice no, white fade yes" );
      ( "light pavement with an autosave",
        arrival ^ "0038-light-pavement",
        "dialog no, choice no, white fade no" );
      ( "a plain dialog box",
        past ^ "0015-text-box",
        "dialog yes, choice no, white fade no" );
    ]

let () =
  Table_test.run "plza story readers"
    (story_cases @ synthetic_badge_cases @ card_cases @ choice_cases
   @ screen_cases
    @ Fixture_frames.shifted_cases (fun m ->
          Story_screen.to_string (Story_screen.read m)))
