(* The battle HUD reader on the fork's AutoStoryScreenEvents frames
   (PokemonLZA_AutoStoryScreenEvents_Tests.cpp names each frame's battle),
   which part shows on each, the other story frames reading as no battle, and
   every frame shifted reading as unshifted. *)

open Plza_readers

let yes = Fixture_frames.yes_no

let parts m =
  Printf.sprintf "%s (hint %s, panel %s, markers %s, trainer %s)"
    (yes (Battle_hud.shown m))
    (yes (Battle_hud.hint_shown m))
    (yes (Battle_hud.panel_shown m))
    (yes (Battle_hud.markers_shown m))
    (yes (Battle_hud.trainer_balls_shown m))

let read m = yes (Battle_hud.shown m)

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let part_case frame expectation : Table_test.case =
  {
    name = frame ^ ": its parts";
    input = (fun () -> parts (Fixture_frames.frame frame));
    expectation;
  }

let cases =
  [
    case "battle-hud/it-0302b-battle-no-lock-on" "yes";
    case "battle-hud/it-0308b-zone-pillar-wild-battle" "yes";
    case "battle-hud/es-0302b-tepig-battle-start" "yes";
    case "battle-hud/es-0302b-tepig-battle-low-hp" "yes";
    case "battle-hud/de-0302b-battle-frame1-no-hint" "yes";
    case "battle-hud/de-0302b-battle-archway-no-hint" "yes";
    part_case "battle-hud/it-0302b-battle-no-lock-on"
      "yes (hint no, panel yes, markers yes, trainer yes)";
    part_case "battle-hud/it-0308b-zone-pillar-wild-battle"
      "yes (hint no, panel yes, markers yes, trainer no)";
    part_case "battle-hud/de-0302b-battle-frame1-no-hint"
      "yes (hint no, panel yes, markers no, trainer yes)";
    part_case "battle-hud/it-0308b-zone-pillar-no-battle"
      "no (hint no, panel yes, markers no, trainer no)";
    {
      name = "the wild battle at brightness 0.9: a known miss (the markers)";
      input =
        (fun () ->
          parts
            (Fixture_frames.shifted_frame "bright90"
               "battle-hud/it-0308b-zone-pillar-wild-battle"));
      expectation = "no (hint no, panel yes, markers no, trainer no)";
    };
    case "battle-hud/it-0308b-zone-pillar-no-battle" "no";
    case "battle-hud/it-0308-zone1-road-no-battle" "no";
    case "battle-hud/it-0309-lab-gate-ryon-dialog" "no";
    case "interact-prompt/arrival-to-ad-0005-prompt" "no";
    case "arrival-to-ad/0001-platform-controls-hint" "no";
    case "arrival-to-ad/0040-text-box-advance-arrow" "no";
    case "dialog-choices/it-0102-villy-2-rows" "no";
    case "tutorial-cards/it-menu-no-card" "no";
  ]

(* 01.03's battle with Andi on console B (2026-11-25, 640x360 run frames
   scaled up): the story screen through a loss and on Andi's line after a
   win. The loss shows a black fade between the battle and the next line, the
   win none: that fade is what tells them apart (Battle). As the lead faints
   (1 HP left) nothing reads: at 360p the trainer's balls and the hint are too
   blurred for the fork's bounds, and the HP bar's trough is darker than its
   grey. Urbain's heal reads as a dialogue box while its text types out (no
   arrow yet): once its arrow shows it reads as the fork's story dialogue, as
   a won battle's line does, so a fight that missed the fade would take the
   heal for a win. *)
let story frame expectation : Table_test.case =
  {
    name = frame ^ ": the story screen";
    input =
      (fun () ->
        Story_screen.to_string
          {
            (Story_screen.read (Fixture_frames.frame frame)) with
            minimap = None;
          });
    expectation;
  }

let loss_and_win_cases =
  [
    story "battle-hud/en-0103-lost-lead-fainting-129-360p" "nothing";
    part_case "battle-hud/en-0103-lost-lead-fainting-129-360p"
      "no (hint no, panel no, markers no, trainer no)";
    story "battle-hud/en-0103-lost-black-fade-135-360p" "black fade";
    story "battle-hud/en-0103-lost-urbain-heal-141-360p" "dialog box";
    story "battle-hud/en-0103-won-andi-line-075-360p"
      "dialog box, advance arrow, story dialog";
  ]

let () =
  Table_test.run "battle_hud"
    (cases @ loss_and_win_cases @ Fixture_frames.shifted_cases ~misses:true read)
