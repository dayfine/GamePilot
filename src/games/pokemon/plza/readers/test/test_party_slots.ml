(* The party count (PokemonLZA_PartyBarDetector.cpp's filled slots) on the
   fork's frames: each frame's cards from switch.probes.jsonl, its bars from
   switch.second.probes.jsonl (probed with tests made from those cards,
   as a live count's second frame). The fork's cases: five filled with slot
   0 selected, sent out, or over bright ground; one filled in Hotel Z's lobby
   and at its elevator's prompt. And a full party of six in Wild Zone 10 (the
   fork's OverworldPartySelectionDetector frames): the bar shows by its D-pad
   marker alone (no empty last slot), and every filled slot not sent out reads
   a bar share of 1.00 (bound 0.5). Every shifted frame reads the same D-pad
   down slot as unshifted. *)

open Plza_readers

let count name =
  let first = Fixture_frames.frame name in
  match Fixture_frames.second name with
  | None -> "no bars probed"
  | Some second -> (
      if not (Party_bar.shown first) then "no party bar"
      else
        match Party_slots.bars second with
        | None -> "bars unread"
        | Some b ->
            string_of_int
              (Party_slots.filled ~sent_out:(Party_marker.down_slot first) b))

let case name frame expectation : Table_test.case =
  { name; input = (fun () -> count frame); expectation }

let cases =
  [
    case "five filled, slot 0 selected (D-pad up), the sixth empty"
      "party-bar/party5-slot0-selected" "5";
    case
      "five filled, slot 0's partner sent out (Poke Ball, no bar), Mareep's \
       bar red"
      "party-bar/party5-slot0-sent-out" "5";
    case "five filled, slot 0's partner sent out, over bright ground"
      "party-bar/party5-b" "5";
    case "one filled in Hotel Z's lobby, five empty"
      "party-bar/de-0205-lobby-start-party1" "1";
    case "one filled at the lobby elevator's A prompt"
      "party-bar/de-0205-elevator-prompt-steady" "1";
  ]

(* The fork's OverworldPartySelectionDetector frames (Wild Zone 10, a full
   party): the digits are the slots of its D-pad up and down markers, 6 for
   none. *)
let full_party_markers = [ (0, 5); (1, 3); (2, 6); (6, 2); (6, 5) ]

let full_party_frame up down =
  Printf.sprintf "party-bar/mac-zone10-party6-%d-%d" up down

let full_party_cases =
  List.map
    (fun (up, down) ->
      let frame = full_party_frame up down in
      case (frame ^ ": six") frame "6")
    full_party_markers

let down_marker m =
  match Party_marker.down_slot m with
  | None -> "none"
  | Some i -> string_of_int i

(* Their D-pad down marker: the slot sent out, "none" for 6. *)
let down_cases =
  List.map
    (fun (up, down) ->
      let frame = full_party_frame up down in
      {
        Table_test.name = frame ^ ": the D-pad down marker";
        input = (fun () -> down_marker (Fixture_frames.frame frame));
        expectation = (if down = 6 then "none" else string_of_int down);
      })
    full_party_markers

(* Their weakest bar, the slot sent out left out (its Pokémon is out, its bar
   gone): its share of HP colours or trough (bound 0.5), at the trough limit
   the fork picks for it. *)
let weakest_bar frame =
  let sent_out = Party_marker.down_slot (Fixture_frames.frame frame) in
  match Option.bind (Fixture_frames.second frame) Party_slots.bars with
  | None -> "bars unread"
  | Some bs ->
      let share (b : Party_slots.bar) =
        if b.hp >= 0.05 then b.relaxed else b.strict
      in
      Printf.sprintf "%.2f"
        (List.fold_left Float.min infinity
           (List.filteri (fun i _ -> Some i <> sent_out) (List.map share bs)))

let headroom_cases =
  List.map
    (fun (frame, expectation) : Table_test.case ->
      {
        name = frame ^ ": the weakest bar";
        input = (fun () -> weakest_bar frame);
        expectation;
      })
    (List.map
       (fun (up, down) -> (full_party_frame up down, "1.00"))
       full_party_markers)

(* Ours, from frames with other expectations. *)
let zone_cases =
  [
    case "03.08 on Wild Zone 1's road: four"
      "battle-hud/it-0308-zone1-road-no-battle" "4";
    case "03.08b at the zone's pillar: five"
      "battle-hud/it-0308b-zone-pillar-no-battle" "5";
    case "03.08b in a wild battle at the pillar: five"
      "battle-hud/it-0308b-zone-pillar-wild-battle" "5";
    (* 640x360 run frames scaled up (console B, 2026-11-25). *)
    case "03.08 at Taunie's rocks: three"
      "party-bar/en-0308-zone1-rocks-party3-014-360p" "3";
    (* At night the bars' green is dim (green about 115, the card about 45):
       no HP colour and no trough, as the fork's limits read it too. *)
    case "six at night in Wild Zone 20: none read"
      "alert-eye/zone-20-dedenne-alakazam-alert-true" "0";
  ]

let () =
  Table_test.run "party_slots"
    (cases @ full_party_cases @ down_cases @ headroom_cases @ zone_cases
    @ Fixture_frames.shifted_cases ~misses:true down_marker)
