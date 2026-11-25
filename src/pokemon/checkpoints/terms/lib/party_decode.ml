module F = Json_field

let slot_fields = [ "slot"; "species" ]

let slot ~where obj : Postconditions.slot =
  (match List.find_opt (fun (k, _) -> not (List.mem k slot_fields)) obj with
  | Some (key, _) -> F.fail "%s%s is not a known field." where key
  | None -> ());
  let slot = F.int ~where "slot" obj in
  if slot < 1 || slot > 6 then
    F.fail "%sslot %d is not a party slot (1-6)." where slot;
  { slot; species = F.string ~where "species" obj }

(* [party_slots] goes with [party_includes] (or alone): [party] names every
   slot already. *)
let party ~where obj : Postconditions.party option =
  let species key = Option.map (F.strings (where ^ key)) (F.find key obj) in
  let slots = F.records ~where "party_slots" obj slot in
  match (species "party", species "party_includes", slots) with
  | Some _, Some _, _ ->
      F.fail "%sparty and party_includes: one or the other, not both." where
  | Some _, None, _ :: _ ->
      F.fail "%sparty_slots goes with party_includes, not party." where
  | Some list, None, [] -> Some (Party_in_order list)
  | None, Some members, slots -> Some (Party_includes { members; slots })
  | None, None, [] -> None
  | None, None, slots -> Some (Party_includes { members = []; slots })
