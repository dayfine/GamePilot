(* The A prompt reader on the fork's AutoStoryDetectors frames
   (PokemonLZA_AutoStoryScreenEvents_Tests.cpp names each frame's events:
   those with interact_prompt read as shown, their neighbours without as not),
   the other story frames reading as no prompt, and every frame shifted
   reading as unshifted. *)

open Plza_readers

let read m = Fixture_frames.yes_no (Interact_prompt.shown m)

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let cases =
  [
    case "interact-prompt/arrival-past-banner-0003-prompt-hint" "yes";
    case "interact-prompt/arrival-to-ad-0005-prompt" "yes";
    case "interact-prompt/arrival-subtitles-0005-prompt-hint" "yes";
    case "interact-prompt/mission-complete-0001-prompt" "yes";
    case "interact-prompt/mission-complete-0003-nothing" "no";
    case "arrival-to-ad/0001-platform-controls-hint" "no";
    case "arrival-to-ad/0007-plaza" "no";
    case "arrival-to-ad/0040-text-box-advance-arrow" "no";
    case "arrival-to-ad/0082-black-fade" "no";
    case "confirm-choices/English_2" "no";
    case "dialog-choices/it-0102-villy-2-rows" "no";
    case "tutorial-cards/it-menu-no-card" "no";
  ]

let () =
  Table_test.run "interact_prompt" (cases @ Fixture_frames.shifted_cases read)
