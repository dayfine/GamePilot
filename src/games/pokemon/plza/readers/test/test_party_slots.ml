(* The party count (PokemonLZA_PartyBarDetector.cpp's filled slots) on the
   fork's frames: each frame's cards from <folder>.probes.jsonl, its bars from
   <folder>.second.probes.jsonl (probed with tests made from those cards,
   as a live count's second frame). The fork's cases: five filled with slot
   0 selected, sent out, or over bright ground; one filled in Hotel Z's lobby
   and at its elevator's prompt. *)

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

let () = Table_test.run "party_slots" (cases @ zone_cases)
