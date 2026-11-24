open Grid_maps
module F = Json_field
open Plan_fields

let money_range ~where obj : Plan.money =
  let min = F.int ~where "min" obj and max = F.int ~where "max" obj in
  if min > max then F.fail "%smin %d is above max %d." where min max;
  Money_range { min; max }

(* [where] ends in "money.": the error names the object. *)
let money ~where obj : Plan.money =
  only ~where [ "min"; "max"; "spent" ] obj;
  let money = String.sub where 0 (String.length where - 1) in
  let range = F.has "min" obj || F.has "max" obj in
  match (F.has "spent" obj, range) with
  | true, true -> F.fail "%s: give min and max, or spent, not both." money
  | true, false -> Money_spent (F.int ~where "spent" obj)
  | false, true -> money_range ~where obj
  | false, false -> F.fail "%s: give min and max, or spent." money

(* The keys naming a count: one of them, with how each reads. *)
let count_keys exact =
  [
    (exact, fun n -> Plan.Count_exactly n);
    ("gained", fun n -> Plan.Count_gained n);
    ("used", fun n -> Plan.Count_gained (-n));
    ("at_least", fun n -> Plan.Count_at_least n);
  ]

(* [where] ends in a dot: the error names the object. *)
let count ~where ~exact obj =
  let keys = count_keys exact in
  match List.filter (fun (key, _) -> F.has key obj) keys with
  | [ (key, of_int) ] -> of_int (F.int ~where key obj)
  | _ ->
      F.fail "%s: give one of %s."
        (String.sub where 0 (String.length where - 1))
        (String.concat ", " (List.map fst keys))

let bag_count ~where obj : Plan.bag_count =
  only ~where [ "item"; "quantity"; "gained"; "used"; "at_least" ] obj;
  {
    bag_item = F.string ~where "item" obj;
    count = count ~where ~exact:"quantity" obj;
  }

(* A number, exactly that many; or an object with a count. *)
let coins ~where obj =
  match F.find "coins" obj with
  | None -> None
  | Some (`Int n) -> Some (Plan.Count_exactly n)
  | Some value ->
      let where = where ^ "coins." in
      let obj = F.as_object where value in
      only ~where [ "exactly"; "gained"; "used"; "at_least" ] obj;
      Some (count ~where ~exact:"exactly" obj)

let knows ~where obj : Plan.knows =
  only ~where [ "species"; "moves" ] obj;
  {
    species = F.string ~where "species" obj;
    moves = F.strings (where ^ "moves") (F.field ~where "moves" obj);
  }

let level ~where obj : Plan.level =
  only ~where [ "species"; "min" ] obj;
  { species = F.string ~where "species" obj; min = F.int ~where "min" obj }

let mark_names = [ "held_item"; "mail"; "none" ]

let marks ~where key obj =
  let path = where ^ key in
  let names = F.strings path (F.field ~where key obj) in
  List.iter
    (fun name ->
      if not (List.mem name mark_names) then
        F.fail "%s: %s is not held_item, mail or none." path name)
    names;
  names

let no_postconditions : Plan.postconditions =
  {
    position = None;
    party = None;
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let postconditions ~where obj : Plan.postconditions =
  only ~where
    [
      "position";
      "party";
      "party_includes";
      "party_slots";
      "items";
      "coins";
      "money";
      "flags";
      "knows";
      "levels";
      "marks";
    ]
    obj;
  let nested key read =
    Option.map
      (fun o -> read ~where:(where ^ key ^ ".") o)
      (F.object_opt ~where key obj)
  in
  {
    position = nested "position" grid_pose;
    party = Party_decode.party ~where obj;
    items = F.records ~where "items" obj bag_count;
    coins = coins ~where obj;
    money = nested "money" money;
    flags =
      Option.fold ~none:[]
        ~some:(F.strings (where ^ "flags"))
        (F.find "flags" obj);
    knows = F.records ~where "knows" obj knows;
    levels = F.records ~where "levels" obj level;
    marks = optional ~where "marks" obj marks;
  }

let of_metadata ~where = function
  | None -> no_postconditions
  | Some metadata ->
      Option.fold ~none:no_postconditions
        ~some:(postconditions ~where:(where ^ "metadata.postconditions."))
        (F.object_opt ~where:(where ^ "metadata.") "postconditions" metadata)
