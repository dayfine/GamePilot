(* The v1 and v2 runtime map formats: v2 decodes to the same v1 JSON, and
   each malformed v2 field is rejected naming it. Ported from
   Pokemon_RuntimeMap_Tests.cpp; each case's input is the fields after a
   fixed name, source and 2x2 tiles. *)

open Grid_maps

type expectation =
  | Parses  (** The map parses. *)
  | Same_as_v1 of string  (** Its v1 form is these fields'. *)
  | Rejected of string  (** Parsing fails naming this. *)

type case = { name : string; input : string; expectation : expectation }

let v2 = {|"format":"pokesim-runtime-map/2",|}

let golden_v2 =
  v2
  ^ {|
    "world":{"name":"Sinnoh","x":0,"y":0},
    "extension":{"zero":0,"false":false},
    "npcs":[
        {"name":"npc","coord":[0,0],"facing":"east","trainer":{"sight":1},"wander":{"min":[0,0],"max":[1,1]}},
        {"name":"npc","coord":[1,0],"hide_flag":"hidden"}
    ],
    "items":[{"name":"pickup","coord":[0,1],"item":"potion","quantity":1}],
    "signs":[{"name":"sign","coord":[1,1]}],
    "interactables":[{"name":"ball","coord":[1,0],"interaction":{"kind":"starter_choice","species":"squirtle"}}],
    "warps":[{"coord":[1,1],"enter":"walk_north","to_map":"House","to_point":"exit"}],
    "patches":[{"coord":[0,1],"glyph":"#","measured_by":"synthetic"}],
    "coord_events":[{"coord":[0,0],"width":1,"length":2,"var":0}]|}

let golden_v1 =
  {|
    "world":{"name":"Sinnoh","x":0,"y":0},
    "extension":{"zero":0,"false":false},
    "objects":[
        {"name":"npc","kind":"npc","x":0,"y":0,"facing":"east","trainer":{"sight":1},"wander":{"x0":0,"y0":0,"x1":1,"y1":1}},
        {"name":"npc","kind":"npc","x":1,"y":0,"hide_flag":"hidden"},
        {"name":"pickup","kind":"item","x":0,"y":1,"item":"potion","quantity":1},
        {"name":"sign","kind":"sign","x":1,"y":1},
        {"name":"ball","kind":"item","x":1,"y":0,"interaction":{"kind":"starter_choice","species":"squirtle"}}
    ],
    "warps":[{"x":1,"y":1,"enter":"walk_north","to_map":"House","to_point":"exit"}],
    "patches":[{"x":0,"y":1,"glyph":"#","measured_by":"synthetic"}],
    "coord_events":[{"x":0,"y":0,"width":1,"length":2,"var":0}]|}

let items record = v2 ^ {|"items":[|} ^ record ^ "]"
let warps record = v2 ^ {|"warps":[|} ^ record ^ "]"
let npcs record = v2 ^ {|"npcs":[|} ^ record ^ "]"
let case name input expectation = { name; input; expectation }

let pickup_cases =
  [
    case "pickup derived name and default quantity"
      (items {|{"coord":[0,1],"source_event":3,"item":"potion"}|})
      (Same_as_v1
         {|"objects":[{"x":0,"y":1,"kind":"item","name":"item_3","source_event":3,"item":"potion","quantity":1}]|});
    case "pickup explicit name and multiple quantity"
      (items
         {|{"name":"gift_cache","coord":[0,1],"source_event":3,"item":"potion","quantity":4}|})
      (Same_as_v1
         {|"objects":[{"x":0,"y":1,"kind":"item","name":"gift_cache","source_event":3,"item":"potion","quantity":4}]|});
    case "pickup named quantity default"
      (items {|{"name":"pickup","coord":[0,1],"item":"potion"}|})
      (Same_as_v1
         {|"objects":[{"x":0,"y":1,"kind":"item","name":"pickup","item":"potion","quantity":1}]|});
    case "pickup missing event"
      (items {|{"coord":[0,1],"item":"potion"}|})
      (Rejected "source_event");
    case "pickup negative event"
      (items {|{"coord":[0,1],"item":"potion","source_event":-1}|})
      (Rejected "source_event");
    case "pickup boolean event"
      (items {|{"coord":[0,1],"item":"potion","source_event":true}|})
      (Rejected "source_event");
    case "pickup overflow event"
      (items {|{"coord":[0,1],"item":"potion","source_event":2147483648}|})
      (Rejected "source_event");
    case "pickup zero quantity"
      (items {|{"coord":[0,1],"name":"p","item":"potion","quantity":0}|})
      (Rejected "quantity");
    case "pickup negative quantity"
      (items {|{"coord":[0,1],"name":"p","item":"potion","quantity":-1}|})
      (Rejected "quantity");
    case "pickup boolean quantity"
      (items {|{"coord":[0,1],"name":"p","item":"potion","quantity":true}|})
      (Rejected "quantity");
    case "pickup null quantity"
      (items {|{"coord":[0,1],"name":"p","item":"potion","quantity":null}|})
      (Rejected "quantity");
    case "pickup float quantity"
      (items {|{"coord":[0,1],"name":"p","item":"potion","quantity":1.5}|})
      (Rejected "quantity");
    case "pickup empty item"
      (items {|{"coord":[0,1],"name":"p","item":""}|})
      (Rejected "item");
  ]

let format_cases =
  [
    case "complete normalized-value parity" golden_v2 (Same_as_v1 golden_v1);
    case "implicit v1" {|"objects":[{"name":"npc","kind":"npc","x":0,"y":0}]|}
      Parses;
    case "explicit v1" {|"format":"pokesim-runtime-map/1"|} Parses;
    case "v2 empty map" {|"format":"pokesim-runtime-map/2"|} Parses;
    case "v2 coordinates and inclusive wander"
      (npcs {|{"name":"npc","coord":[0,0],"wander":{"min":[0,0],"max":[1,1]}}|})
      Parses;
    case "unsupported version" {|"format":"pokesim-runtime-map/99"|}
      (Rejected "format");
    case "nonstring version" {|"format":2|} (Rejected "format");
    case "v1 typed section" {|"npcs":[]|} (Rejected "npcs");
    case "v2 legacy section" (v2 ^ {|"objects":[]|}) (Rejected "objects");
  ]

let position_cases =
  [
    case "mixed v2 position"
      (warps {|{"coord":[0,0],"x":0}|})
      (Rejected "warps[0].coord");
    case "mixed v1 position" {|"warps":[{"x":0,"y":0,"coord":[0,0]}]|}
      (Rejected "warps[0].coord");
    case "missing v2 position" (warps "{}") (Rejected "warps[0].coord");
    case "short position" (warps {|{"coord":[0]}|}) (Rejected "warps[0].coord");
    case "long position"
      (warps {|{"coord":[0,0,0]}|})
      (Rejected "warps[0].coord");
    case "floating coordinate"
      (warps {|{"coord":[0.5,0]}|})
      (Rejected "coord[0]");
    case "boolean coordinate"
      (warps {|{"coord":[false,0]}|})
      (Rejected "coord[0]");
    case "overflow coordinate"
      (warps {|{"coord":[2147483648,0]}|})
      (Rejected "coord[0]");
    case "outside map" (warps {|{"coord":[3,0]}|}) (Rejected "outside");
    case "mixed wander"
      (npcs
         {|{"name":"npc","coord":[0,0],"wander":{"min":[0,0],"max":[1,1],"x0":0}}|})
      (Rejected "wander.min");
    case "reversed wander"
      (npcs {|{"name":"npc","coord":[0,0],"wander":{"min":[1,1],"max":[0,0]}}|})
      (Rejected "min <= max");
    case "bad coordinate event"
      (v2 ^ {|"coord_events":[{"coord":[0,true]}]|})
      (Rejected "coord_events[0].coord[1]");
  ]

let group_cases =
  [
    case "redundant kind"
      (v2 ^ {|"signs":[{"name":"sign","coord":[0,0],"kind":"sign"}]|})
      (Rejected "kind");
    case "starter interaction"
      (v2
     ^ {|"interactables":[{"name":"ball","coord":[0,0],"interaction":{"kind":"starter_choice","species":"squirtle"}}]|}
      )
      Parses;
    case "interaction has item"
      (v2
     ^ {|"interactables":[{"coord":[0,0],"interaction":{"kind":"starter_choice"},"item":"potion"}]|}
      )
      (Rejected "item reward");
    case "interaction missing kind"
      (v2 ^ {|"interactables":[{"coord":[0,0],"interaction":{}}]|})
      (Rejected "interaction");
    case "item has interaction"
      (items {|{"coord":[0,0],"interaction":{"kind":"starter_choice"}}|})
      (Rejected "interactables");
  ]

let document fields =
  Yojson.Safe.from_string
    ({|{"name":"ContractMap","source":{"decomp_file":"synthetic","revision":"fixture","date":"2026-11-06"},"tiles":["..",".."],|}
   ^ fields ^ "}")

(* JSON values equal up to the order of object keys. *)
let rec same (a : Yojson.Safe.t) (b : Yojson.Safe.t) =
  match (a, b) with
  | `Assoc x, `Assoc y ->
      let sort = List.sort (fun (k, _) (l, _) -> String.compare k l) in
      List.length x = List.length y
      && List.for_all2
           (fun (k, v) (l, w) -> k = l && same v w)
           (sort x) (sort y)
  | `List x, `List y -> List.length x = List.length y && List.for_all2 same x y
  | _ -> a = b

let source_name = "Maps/contract.json"

let same_as_v1 input v1_fields =
  let where = source_name ^ ": " in
  match Runtime_format.to_v1 ~where input with
  | exception Json_field.Invalid message -> Error message
  | v1 when not (same v1 (Runtime_format.to_v1 ~where (document v1_fields))) ->
      Error ("v1 form differs: " ^ Yojson.Safe.to_string v1)
  | _ -> Result.map (fun _ -> ()) (Map_file.parse ~source_name input)

let run_case { name; input; expectation } =
  let input = document input in
  Table_test.report name
    (match (expectation, Map_file.parse ~source_name input) with
    | Parses, Ok _ -> Ok ()
    | Same_as_v1 v1_fields, Ok _ -> same_as_v1 input v1_fields
    | Rejected part, Error message ->
        Check.mentions message [ part; source_name ]
    | Rejected _, Ok _ -> Error "parsed"
    | (Parses | Same_as_v1 _), Error message -> Error message)

let () =
  List.iter run_case (pickup_cases @ format_cases @ position_cases @ group_cases);
  Table_test.finish ()
