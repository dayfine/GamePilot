(* The lock-on name plate and its caught mark (PokemonLZA_CaughtMarkReader.cpp)
   on the fork's drawn plates (PokemonLZA_Detectors_Tests.cpp):
   the bar from the frame, the mark from the second read made from it. *)

open Plza_readers

let read_frames first second =
  match Lock_plate.bar first with
  | None -> "no plate"
  | Some bar -> (
      match Option.map (fun m -> Lock_plate.caught m bar) second with
      | Some (Some true) -> "a plate with the caught mark"
      | Some (Some false) -> "a plate with no caught mark"
      | Some None | None -> "mark unread")

let read name =
  read_frames (Fixture_frames.frame name) (Fixture_frames.second name)

let case name frame expectation : Table_test.case =
  { name; input = (fun () -> read frame); expectation }

let cases =
  [
    case "the plate's bar and the player's HP bar on bright grass"
      "synthetic/plate-and-player-bar-on-grass" "a plate with no caught mark";
    case "a plate with the gender mark only (Scatterbug, not caught)"
      "synthetic/plate-gender-mark-only" "a plate with no caught mark";
    case "a plate with the gender mark and the Poke Ball (Bunnelby, caught)"
      "synthetic/plate-gender-and-ball-marks" "a plate with the caught mark";
    (* Ours: the female mark is pinkish red round a white sign, which the
       fork's counts took for the Poke Ball. *)
    case "a plate with the female mark only (not caught)"
      "synthetic/plate-female-mark-only" "a plate with no caught mark";
    case "a plate with the female mark and the Poke Ball (caught)"
      "synthetic/plate-female-and-ball-marks" "a plate with the caught mark";
    case "the player's HP bar alone" "synthetic/player-bar-alone" "no plate";
    case "bright grass alone" "synthetic/bright-grass-alone" "no plate";
    case "21-fourth-species's Scatterbug under ZL (not caught)"
      "lock-plate/en-0308-scatterbug-not-caught-038-360p"
      "a plate with no caught mark";
    (* 640x360 run frames (console B, 2026-11-25): the plates that 21-fourth-species and
       22-fifth-species read as caught, and the Bunnelby that was. *)
    case "21-fourth-species's female Scatterbug (not caught)"
      "lock-plate/en-0308-scatterbug-female-not-caught-041-360p"
      "a plate with no caught mark";
    case "22-fifth-species's female Weedle (not caught)"
      "lock-plate/en-0308a-weedle-female-not-caught-029-360p"
      "a plate with no caught mark";
    case
      "22-fifth-species's female Weedle, thrown at and caught (a new species)"
      "lock-plate/en-0308a-weedle-female-thrown-at-036-360p"
      "a plate with no caught mark";
    case "22-fifth-species's Bunnelby (caught at 20-first-catches)"
      "lock-plate/en-0308a-bunnelby-caught-036-360p"
      "a plate with the caught mark";
    case "20-first-catches's Bunnelby battle: no lock on"
      "alert-eye/en-0307-bunnelby-battle-113-360p" "no plate";
  ]

let plate m =
  match Lock_plate.bar m with
  | Some b ->
      let x, y = Lock_plate.centre b in
      Printf.sprintf "a plate at (%.2f, %.2f)" x y
  | None -> "no plate"

(* Every frame where a plate's bar reads (HP bars in a menu read too: the
   bar is read only under ZL). *)
let plates =
  [
    ("move-symbols/0303-andi-zl-held-1", "a plate at (0.53, 0.52)");
    ("move-symbols/0303-andi-zl-held-3", "a plate at (0.52, 0.51)");
    ("move-symbols/0303-andi-zl-held-target-4", "a plate at (0.53, 0.48)");
    ("move-symbols/0303-andi-zl-held-target-5", "a plate at (0.53, 0.49)");
    ("party-bar/party5-slot0-selected", "a plate at (0.54, 0.40)");
    ("tutorial-cards/it-menu-no-card", "a plate at (0.49, 0.37)");
    ( "lock-plate/en-0308-scatterbug-not-caught-038-360p",
      "a plate at (0.53, 0.44)" );
    ("synthetic/plate-and-player-bar-on-grass", "a plate at (0.52, 0.49)");
    ("synthetic/plate-gender-and-ball-marks", "a plate at (0.52, 0.49)");
    ("synthetic/plate-gender-mark-only", "a plate at (0.52, 0.49)");
    ("synthetic/plate-female-mark-only", "a plate at (0.52, 0.49)");
    ("synthetic/plate-female-and-ball-marks", "a plate at (0.52, 0.49)");
    ( "lock-plate/en-0308-scatterbug-female-not-caught-041-360p",
      "a plate at (0.53, 0.43)" );
    ( "lock-plate/en-0308a-weedle-female-not-caught-029-360p",
      "a plate at (0.53, 0.42)" );
    ( "lock-plate/en-0308a-weedle-female-thrown-at-036-360p",
      "a plate at (0.52, 0.58)" );
    ("lock-plate/en-0308a-bunnelby-caught-036-360p", "a plate at (0.53, 0.39)");
  ]

let frame_cases =
  List.map
    (fun (name, expectation) : Table_test.case ->
      {
        name = name ^ ": the plate";
        input = (fun () -> plate (Fixture_frames.frame name));
        expectation;
      })
    plates

let no_plate_elsewhere : Table_test.case =
  {
    name = "no other frame reads a plate";
    input =
      (fun () ->
        Fixture_frames.frames
        |> List.filter_map (fun (path, probes) ->
               let name = Fixture_frames.frame_name path in
               if List.mem_assoc name plates then None
               else if plate (Fixture_frames.measurements probes) = "no plate"
               then None
               else Some name)
        |> String.concat ", ");
    expectation = "";
  }

(* The plate's green is a tight range, as the fork's: a few shifts lose it,
   or find a bar in a menu or a banner. *)
let shift_misses =
  [
    ("party-bar/party5-slot0-selected", "bright110");
    ("party-bar/party5-slot0-selected", "gplus12");
    ("party-bar/party5-slot0-selected", "rminus12");
    ("synthetic/autosave-mint-banner-bands", "bright90");
    ("tutorial-cards/it-menu-no-card", "bright90");
    ("tutorial-cards/it-menu-no-card", "gplus12");
    (* Not lost: with blue up 12 the 640x360 bar loses its blurred bottom
       row, and its centre (0.576) rounds to 0.57. *)
    ("lock-plate/en-0308a-weedle-female-thrown-at-036-360p", "bplus12");
  ]

let shifted_cases =
  List.filter
    (fun (c : Table_test.case) ->
      not
        (List.exists
           (fun (frame, shift) ->
             c.name = Printf.sprintf "%s, %s: reads as unshifted" frame shift)
           shift_misses))
    (Fixture_frames.shifted_cases ~misses:true plate)

(* The console frame of a caught Mareep's plate (the Poke Ball by its gender
   mark): the mark reads. *)
let mareep : Table_test.case =
  {
    name = "party5-slot0-selected: Mareep's plate has the caught mark";
    input = (fun () -> read "party-bar/party5-slot0-selected");
    expectation = "a plate with the caught mark";
  }

(* The caught mark on every shifted frame with a plate, its second read made
   from the shifted frame's own bar: as on the frame itself. *)
let shifted_mark_cases =
  List.filter_map
    (fun (path, probes) : Table_test.case option ->
      let shift, name = Fixture_frames.shift_and_frame path in
      if List.mem_assoc name plates then
        Some
          {
            name =
              Printf.sprintf "%s, %s: the mark reads as unshifted" name shift;
            input =
              (fun () ->
                read_frames
                  (Fixture_frames.measurements probes)
                  (Fixture_frames.shifted_second shift name));
            expectation = read name;
          }
      else None)
    Fixture_frames.shifted

let () =
  Table_test.run "lock_plate"
    (cases
    @ (mareep :: no_plate_elsewhere :: frame_cases)
    @ shifted_cases @ shifted_mark_cases)
