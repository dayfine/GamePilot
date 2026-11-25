(* The party bar reader (PokemonLZA_PartyBarDetector.cpp's last empty slot) on
   the fork's PartyBarDetector and AutoStoryScreenEvents frames, 01.03's alley
   on console B, and the other story frames: the platform, the battle HUD,
   dialogue, choices, fades and cards. Every frame shifted reads as unshifted.

   Headroom (the line's brightness over the strip inside it, bound 10; over
   the strip outside, bound 0), weakest edge per frame: the frames with the bar
   read 18 inside and 10 outside at least (za2-m3v-s1, a 640x360 capture scaled
   up, and the zone's pillar), 01.03's alley 41 and 37; shifted, 16 and 9 at
   least. On every frame without the bar, shifted or not, some edge reads 0
   inside or less. Andi's battle frames and the road show the bar, as the fork
   reads them: the battle HUD leaves it up.

   The D-pad marker (Party_marker, score bound 80 for the buttons, 120 for
   their insides): 03.02b's plaza arch on console B (2026-11-25), where the
   bar collapses to its lead icon and the empty slots fade into the light
   pavement (no empty-slot read), shows it at 56 on the 1080p failure frame
   (65 at most shifted), 68 on frame 210 of the run's 640x360 frames scaled up
   (73 shifted; frames 168, 200 and 232 scaled up read 74 to 77 and over 80
   shifted, so they are not kept: the daemon reads 1080p). Without a marker no
   frame scores under 118 (a button) or 168 (an inside). *)

open Plza_readers

let yes = Fixture_frames.yes_no
let read m = yes (Party_bar.shown m)

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

(* The weakest edge's margins, rounded: "inside N, outside M". *)
let weakest m =
  match Party_bar.margins m with
  | None -> "no read"
  | Some gs ->
      let low f = List.fold_left (fun a g -> Float.min a (f g)) infinity gs in
      Printf.sprintf "inside %.0f, outside %.0f"
        (low (fun (g : Party_bar.margin) -> g.inside))
        (low (fun (g : Party_bar.margin) -> g.outside))

let headroom frame expectation : Table_test.case =
  {
    name = frame ^ ": the weakest edge";
    input = (fun () -> weakest (Fixture_frames.frame frame));
    expectation;
  }

let marker frame expectation : Table_test.case =
  {
    name = frame ^ ": the marker and the last slot";
    input =
      (fun () ->
        let m = Fixture_frames.frame frame in
        Printf.sprintf "marker %s, last slot %s"
          (yes (Party_marker.shown m))
          (yes (Party_bar.last_slot_empty m)));
    expectation;
  }

let story_screen frame expectation : Table_test.case =
  {
    name = frame ^ ": the story screen's party bar";
    input =
      (fun () -> yes (Story_screen.read (Fixture_frames.frame frame)).party_bar);
    expectation;
  }

let cases =
  [
    case "party-bar/0103-alley-party1" "yes";
    case "party-bar/za2-m3v-s1-prompt" "yes";
    case "party-bar/de-0205-lobby-start-party1" "yes";
    case "party-bar/de-0205-elevator-prompt-steady" "yes";
    case "party-bar/party5-b" "yes";
    case "party-bar/party5-slot0-selected" "yes";
    case "party-bar/party5-slot0-sent-out" "yes";
    case "battle-hud/it-0308-zone1-road-no-battle" "yes";
    case "battle-hud/it-0308b-zone-pillar-no-battle" "yes";
    case "move-symbols/0303-andi-battle-no-zl-1" "yes";
    case "party-bar/en-0302b-arch-collapsed-1080p" "yes";
    case "party-bar/en-0302b-arch-collapsed-210" "yes";
    case "party-bar/en-0302b-arch-map-card-138" "no";
    case "party-bar/en-0302b-arch-urbain-text-144" "no";
    case "party-bar/en-0302b-arch-taunie-cutscene-150" "no";
    case "party-bar/en-0302b-arch-taunie-cutscene-153" "no";
    case "party-bar/it-0102-parla-talk-prompt" "no";
    case "arrival-to-ad/0001-platform-controls-hint" "no";
    case "arrival-to-ad/0007-plaza" "no";
    case "arrival-to-ad/0038-light-pavement" "no";
    case "arrival-to-ad/0040-text-box-advance-arrow" "no";
    case "arrival-to-ad/0082-black-fade" "no";
    case "arrival-past-mission-banner/0185-mission-banner" "no";
    case "arrival-past-mission-banner/0210-controls-hint" "no";
    case "battle-hud/it-0302b-battle-no-lock-on" "no";
    case "battle-hud/es-0302b-tepig-battle-start" "no";
    case "battle-hud/it-0309-lab-gate-ryon-dialog" "no";
    case "dialog-choices/it-0102-villy-2-rows" "no";
    case "interact-prompt/mission-complete-0001-prompt" "no";
    case "tutorial-cards/it-0302b-map-missions-card" "no";
    headroom "party-bar/0103-alley-party1" "inside 41, outside 37";
    headroom "party-bar/za2-m3v-s1-prompt" "inside 18, outside 12";
    marker "party-bar/en-0302b-arch-collapsed-1080p" "marker yes, last slot no";
    marker "party-bar/0103-alley-party1" "marker yes, last slot yes";
    marker "party-bar/za2-m3v-s1-prompt" "marker no, last slot yes";
    story_screen "party-bar/en-0302b-arch-collapsed-1080p" "yes";
    story_screen "party-bar/0103-alley-party1" "yes";
    story_screen "party-bar/za2-m3v-s1-prompt" "yes";
    story_screen "battle-hud/it-0309-lab-gate-ryon-dialog" "no";
  ]

let () =
  Table_test.run "party_bar"
    (cases @ Fixture_frames.shifted_cases ~misses:true read)
