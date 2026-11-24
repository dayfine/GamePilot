open Grid_maps
module F = Json_field
open Plan_fields

let money ~where obj : Plan.money =
  only ~where [ "min"; "max" ] obj;
  let min = F.int ~where "min" obj and max = F.int ~where "max" obj in
  if min > max then F.fail "%smin %d is above max %d." where min max;
  { min; max }

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

let party ~where obj : Plan.party option =
  let species key = Option.map (F.strings (where ^ key)) (F.find key obj) in
  match (species "party", species "party_includes") with
  | Some _, Some _ ->
      F.fail "%sparty and party_includes: one or the other, not both." where
  | Some list, None -> Some (Party_in_order list)
  | None, Some list -> Some (Party_includes list)
  | None, None -> None

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
    party = party ~where obj;
    items = F.records ~where "items" obj item;
    coins = optional ~where "coins" obj F.int;
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
