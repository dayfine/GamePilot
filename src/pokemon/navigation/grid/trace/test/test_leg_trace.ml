(* The leg record's line word for word, the route log's leg lines read back,
   and the tracer's records for a leg that ends, one cut off by the next, and
   one with a wild battle on the way. Ported from Pokemon_LegTrace_Tests.cpp. *)

open Grid_geometry
open Grid_trace

let tile map x y = { Route_tile.map; pos = { Tile_pos.x; y } }
let tiles_text = function [] -> "none" | tiles -> Route_tile.describe tiles

let plan_text = function
  | None -> "none"
  | Some (plan : Leg_record.plan) ->
      Printf.sprintf "%s %d %s -> %s"
        (Direction.name plan.direction)
        plan.tiles
        (Leg_record.End_kind.name plan.end_kind)
        (tiles_text plan.ends)

(* The lines a tracer emits for [script], one a line. *)
let traced script =
  let out = Buffer.create 256 in
  let tracer =
    Leg_tracer.create (fun line ->
        Buffer.add_string out line;
        Buffer.add_char out '\n')
  in
  script tracer;
  Buffer.contents out

let walk ?(wild_battles = 0) chunks walked_ms =
  { Leg_tracer.chunks; walked_ms; wild_battles; tapped = None }

let tap_record =
  {
    Leg_record.checkpoint = "00.04";
    event = "to_the_signs_row";
    leg = 1;
    plan =
      {
        direction = North;
        tiles = 1;
        end_kind = Tile;
        ends = [ tile "Route 201" 57 4 ];
      };
    moved = Some 1;
    chunks = 1;
    walked_ms = 800;
    end_tiles = [ tile "Route 201" 57 4 ];
    known = Counted;
    interrupts = [];
    note = None;
  }

let cut_off tracer =
  Leg_tracer.begin_event tracer ~checkpoint:"00.04" ~event:"beside_mom";
  Leg_tracer.begin_leg tracer (Leg_record.plan West 2 Open);
  Leg_tracer.begin_leg tracer (Leg_record.plan North 1 Wall);
  Leg_tracer.walked tracer (walk 3 640);
  Leg_tracer.begin_event tracer ~checkpoint:"00.04" ~event:"mom"

let battle_on_the_way tracer =
  Leg_tracer.begin_event tracer ~checkpoint:"00.04b" ~event:"to_catch_grass";
  Leg_tracer.begin_leg tracer (Leg_record.plan South 4 Wall);
  Leg_tracer.walked tracer (walk ~wild_battles:1 2 500);
  Leg_tracer.walked tracer (walk 2 400);
  Leg_tracer.end_leg tracer [ tile "Route 202" 20 27 ] Wall;
  Leg_tracer.end_event tracer

let case name input expectation = { Table_test.name; input; expectation }

let cases =
  [
    case "a tap leg's line"
      (fun () -> Leg_record.to_line tap_record)
      "[Leg] \
       {\"checkpoint\":\"00.04\",\"chunks\":1,\"dir\":\"north\",\"end\":[[\"Route \
       201\",57,4]],\"end_kind\":\"tile\",\"event\":\"to_the_signs_row\",\"interrupts\":[],\"known\":\"counted\",\"leg\":1,\"moved\":1,\"ms\":800,\"planned_end\":[[\"Route \
       201\",57,4]],\"tiles\":1}";
    case "tiles read back"
      (fun () ->
        tiles_text
          (Route_tile.parse_list "Route 202 (23, 25), Mom's House (30, -1)"))
      "Route 202 (23, 25), Mom's House (30, -1)";
    case "no tiles in other text"
      (fun () -> tiles_text (Route_tile.parse_list "an unknown tile"))
      "none";
    case "a wall leg line read back"
      (fun () ->
        plan_text
          (Leg_record.plan_of_leg_line
             "Leg 1/2: east 15 (to wall) to Route 202 (23, 25), Route 202 (30, \
              26)"))
      "east 15 wall -> Route 202 (23, 25), Route 202 (30, 26)";
    case "an open leg line read back"
      (fun () ->
        plan_text
          (Leg_record.plan_of_leg_line
             "Leg 3/3: west 1 (open) to Twinleaf Town (7, 9)"))
      "west 1 open -> Twinleaf Town (7, 9)";
    case "not a leg line"
      (fun () ->
        plan_text (Leg_record.plan_of_leg_line "[Route] Turning west."))
      "none";
    case "a leg cut off by the next, and by its event's end"
      (fun () -> traced cut_off)
      "[Leg] \
       {\"checkpoint\":\"00.04\",\"chunks\":0,\"dir\":\"west\",\"end\":[],\"end_kind\":\"open\",\"event\":\"beside_mom\",\"interrupts\":[],\"known\":\"unknown\",\"leg\":1,\"ms\":0,\"planned_end\":[],\"tiles\":2}\n\
       [Leg] \
       {\"checkpoint\":\"00.04\",\"chunks\":3,\"dir\":\"north\",\"end\":[],\"end_kind\":\"wall\",\"event\":\"beside_mom\",\"interrupts\":[],\"known\":\"unknown\",\"leg\":2,\"ms\":640,\"planned_end\":[],\"tiles\":1}\n";
    case "a wild battle on the way, two walks to the wall"
      (fun () -> traced battle_on_the_way)
      "[Leg] \
       {\"checkpoint\":\"00.04b\",\"chunks\":4,\"dir\":\"south\",\"end\":[[\"Route \
       202\",20,27]],\"end_kind\":\"wall\",\"event\":\"to_catch_grass\",\"interrupts\":[\"wild_battle\"],\"known\":\"wall\",\"leg\":1,\"ms\":900,\"planned_end\":[],\"tiles\":4}\n";
  ]

let () = Table_test.run "LegTrace" cases
