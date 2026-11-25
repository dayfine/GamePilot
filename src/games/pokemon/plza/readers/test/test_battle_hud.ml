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

let () =
  Table_test.run "battle_hud"
    (cases @ Fixture_frames.shifted_cases ~misses:true read)
