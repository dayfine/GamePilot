(* The Confirm Choices reader on the fork's frames
   (PokemonLZA_IntroScreens_Tests.cpp: AutoStoryConfirmChoices/<language>_<row>
   reads as its row), the story frames reading as no such screen, and every
   frame shifted reading as unshifted. *)

open Plza_readers

let row m =
  match Confirm_choices.read m with Some r -> string_of_int r | None -> "none"

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> row (Fixture_frames.frame frame));
    expectation;
  }

let cases =
  [
    case "confirm-choices/English_0" "0";
    case "confirm-choices/English_1" "1";
    case "confirm-choices/English_2" "2";
    case "confirm-choices/German_2" "2";
    case "confirm-choices/Japanese_1" "1";
    case "arrival-to-ad/0001-platform-controls-hint" "none";
    case "arrival-to-ad/0065-text-box-choice-box" "none";
    case "arrival-to-ad/0082-black-fade" "none";
    case "dialog-choices/it-0102-villy-2-rows" "none";
    case "tutorial-cards/it-menu-no-card" "none";
  ]

let () =
  Table_test.run "confirm_choices" (cases @ Fixture_frames.shifted_cases row)
