(* The minimap reader (PokemonLZA_MinimapMatch.cpp) on the fork's recorded
   start frames (CommandLineTests PokemonLZA/AutoStoryStarts, Spanish, console
   B) and 03.03's plaza arch on console B (2026-11-25), where 03.03 ends and
   03.04 starts, and frames with no minimap. The references keep the fork's
   numbers: 03.03-start is our 03.04's start, 03.06-start our 03.08's and
   03.07-start our 03.09's.

   Headroom (bound 30): 03.04's start reads 1 from its own reference, the arch
   3 (6 on frame 210 scaled up from 640x360), 03.08's 1, 03.09's 3; the
   Pokémon Center's counter, a spot no start names, matches nothing (49 at the
   nearest). The fork's frames are named one off: its Spanish_0305_start.png
   is 03.08's start (outside the Center, where 03.07 ends; the fork has no
   03.05), as its 03.06 reference says it was recorded on, and
   Spanish_0306_start.png is the counter inside; here they are es-0306-start
   and es-center-counter. The shifted fixture leaves the minimap out
   (write_probe_spec.ml): each channel is scaled to the reference before
   comparing; the fork measured its 03.04's start 20% darker at 2.2 and 20%
   brighter at 21.9. *)

open Plza_readers

let name = function Some n -> n | None -> "none"
let read m = name (Minimap.read m)

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

(* The nearest reference and its distance, rounded. *)
let nearest m =
  match Minimap.distances m with
  | None -> "no read"
  | Some ds ->
      let n, d =
        List.fold_left
          (fun (bn, bd) (n, d) -> if d < bd then (n, d) else (bn, bd))
          ("none", infinity) ds
      in
      Printf.sprintf "%s at %.0f" n d

let headroom frame expectation : Table_test.case =
  {
    name = frame ^ ": the nearest reference";
    input = (fun () -> nearest (Fixture_frames.frame frame));
    expectation;
  }

let story_screen frame expectation : Table_test.case =
  {
    name = frame ^ ": the story screen's minimap";
    input =
      (fun () -> name (Story_screen.read (Fixture_frames.frame frame)).minimap);
    expectation;
  }

let cases =
  [
    {
      Table_test.name = "every reference parses";
      input = (fun () -> String.concat ", " Minimap.reference_names);
      expectation = "03.03-start, 03.04-start, 03.06-start, 03.07-start";
    };
    case "minimap/es-0303-start" "03.03-start";
    case "minimap/es-0306-start" "03.06-start";
    case "minimap/es-center-counter" "none";
    case "minimap/es-0307-start" "03.07-start";
    case "party-bar/en-0302b-arch-collapsed-1080p" "03.03-start";
    case "party-bar/en-0302b-arch-collapsed-210" "03.03-start";
    case "party-bar/0103-alley-party1" "none";
    case "party-bar/en-0302b-arch-taunie-cutscene-150" "none";
    case "arrival-to-ad/0007-plaza" "none";
    case "battle-hud/it-0308-zone1-road-no-battle" "none";
    headroom "minimap/es-0303-start" "03.03-start at 1";
    headroom "minimap/es-0306-start" "03.06-start at 1";
    headroom "minimap/es-center-counter" "03.03-start at 49";
    headroom "party-bar/en-0302b-arch-collapsed-1080p" "03.03-start at 3";
    story_screen "party-bar/en-0302b-arch-collapsed-1080p" "03.03-start";
    story_screen "party-bar/en-0302b-arch-urbain-text-144" "none";
  ]

let () = Table_test.run "minimap" cases
