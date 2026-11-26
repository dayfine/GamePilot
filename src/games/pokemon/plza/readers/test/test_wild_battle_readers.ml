(* The wild battle's readers, the catches' [wild_battle_on]: the alert eye
   (PokemonLZA_AlertEyeDetector.cpp) on ten of the fork's AlertEyeDetector
   frames (CommandLineTests, PokemonLZA/AlertEyeDetector, png kept as jpg) and
   03.12's wild battle at the zone's pillar, and 03.09's Bunnelby battle (a
   640x360 run frame of console B scaled up, 2026-11-25: 44.5; the frame
   after the catch reads none). The Run prompt
   (PokemonLZA_RunFromBattleDetector.cpp), which the fork has no test frame
   of, on none. Every other story frame reads neither. Every frame shifted
   reads as unshifted, but for the known misses (Fixture_frames).

   Headroom (score bound 60 for the eye): the eye on the bar scores 6.6 to
   25.9, the bigger eye as the bar first shows 28.1 and 30.3, the pillar's 30.3,
   and Zone 6's translucent first frame 51.1; shifted, 35.5 at most but for the
   translucent one (71.4, a known miss). A blob of the eye's shape on a frame
   without it scores 69.3 at least, shifted or not (03.01's arrival text
   box). The Run prompt (bound 80): no frame shows it, and a blob of its shape
   on one scores 81.7 at least, shifted or not (Parla's talk prompt), so its
   bound is unchecked against a frame with it. 03.09's tutorial battles show
   no Run prompt (console B, 2026-11-25): the alert eye is what reads them. *)

open Plza_readers

let yes = Fixture_frames.yes_no

let read m =
  Printf.sprintf "eye %s, Run %s"
    (yes (Alert_eye.shown m))
    (yes (Run_prompt.shown m))

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let eye = "eye yes, Run no"
let neither = "eye no, Run no"

let eye_frames =
  [
    "alert-eye/lab-beldum-alpha-alert-true";
    "alert-eye/zone-15-gourgeist-alert-true";
    "alert-eye/zone-17-chespin-alert-true";
    "alert-eye/zone-20-dedenne-alakazam-alert-true";
    "alert-eye/zone-6-houndour-1-true";
    "alert-eye/zone-6-big-eye-1-true";
    "alert-eye/zone-6-initial-eye-1-true";
    "alert-eye/zone-6-translucent-1-true";
    "battle-hud/it-0308b-zone-pillar-wild-battle";
    "alert-eye/en-0307-bunnelby-battle-113-360p";
  ]

let name_of path = Fixture_frames.frame_name path

let cases =
  List.map
    (fun (path, _) ->
      let name = name_of path in
      case name (if List.mem name eye_frames then eye else neither))
    Fixture_frames.frames

let () =
  Table_test.run "wild_battle_readers"
    (cases @ Fixture_frames.shifted_cases ~misses:true read)
