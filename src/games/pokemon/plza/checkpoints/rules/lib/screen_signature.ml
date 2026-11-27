type t = {
  talk_prompt : bool option;
  wild_zone : bool option;
  near_rocks : bool option;
  party : int option;
  minimap : string option;
}

let nothing =
  {
    talk_prompt = None;
    wild_zone = None;
    near_rocks = None;
    party = None;
    minimap = None;
  }

let flag ~yes ~no = Option.map (fun b -> if b then yes else no)

let to_string s =
  match
    List.filter_map Fun.id
      [
        flag ~yes:"talk prompt" ~no:"no talk prompt" s.talk_prompt;
        flag ~yes:"in a wild zone" ~no:"not in a wild zone" s.wild_zone;
        flag ~yes:"near Taunie's rocks" ~no:"not near Taunie's rocks"
          s.near_rocks;
        Option.map (Printf.sprintf "party %d") s.party;
        Option.map (( ^ ) "minimap ") s.minimap;
      ]
  with
  | [] -> "nothing read"
  | parts -> String.concat ", " parts

let confirmed ~known r =
  let agrees k v = Option.is_none k || k = v in
  r <> nothing
  && agrees known.talk_prompt r.talk_prompt
  && agrees known.wild_zone r.wild_zone
  && agrees known.near_rocks r.near_rocks
  && agrees known.party r.party
  && agrees known.minimap r.minimap
