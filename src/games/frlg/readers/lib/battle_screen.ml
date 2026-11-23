(* The teal of the text box, (40, 81, 106), as channel shares; the gold band
   of its frame; the sand backgrounds the HP box tests exclude. *)
let box_teal : Wire.rgb = { r = 0.176; g = 0.357; b = 0.467 }
let frame_gold : Wire.rgb = { r = 0.493; g = 0.391; b = 0.116 }
let player_sand : Wire.rgb = { r = 0.4468; g = 0.3528; b = 0.2004 }
let foe_sand : Wire.rgb = { r = 0.4663; g = 0.3716; b = 0.1621 }

(* The fork's tolerances: teal within 0.25 and stddev sum 20, gold within 0.1
   and 40, the white line up to stddev sum 20, sand within 0.25 and 20. *)
let teal_distance = 0.25
let teal_stddev = 20.
let gold_distance = 0.1
let gold_stddev = 40.
let line_white_stddev = 20.

(* The level-up box's slate border, (120, 115, 140), as channel shares. *)
let level_up_slate : Wire.rgb = { r = 0.320; g = 0.307; b = 0.373 }

(* The move menu's frame is (41, 49, 49): a channel sum of 139. *)
let divider_max_sum = 200.
let divider_stddev = 20.

(* An HP box's off-white edge (255, 255, 235) and dark teal edge (72, 106,
   98), as channel sum ranges. *)
let light_edge_min = 680.
let light_edge_max = 770.
let dark_edge_min = 220.
let dark_edge_max = 320.
let edge_stddev = 20.

let boxes : (string * Wire.box) list =
  [
    ( "battle.box.top",
      { x = 0.0372308; y = 0.750154; w = 0.925538; h = 0.00934615 } );
    ( "battle.box.right",
      { x = 0.956615; y = 0.7595; w = 0.00615385; h = 0.185885 } );
    ("battle.box.line", { x = 0.0385; y = 0.7337; w = 0.923; h = 0.0058 });
    ("battle.box.gold", { x = 0.0385; y = 0.7163; w = 0.923; h = 0.0087 });
    ( "battle.menu.top",
      { x = 0.528308; y = 0.742885; w = 0.439385; h = 0.00830769 } );
    ( "battle.menu.right",
      { x = 0.961538; y = 0.752231; w = 0.00615385; h = 0.200423 } );
    ( "battle.menu.box_top",
      { x = 0.036; y = 0.749115; w = 0.459077; h = 0.0135 } );
    ( "battle.menu.box_right",
      { x = 0.490154; y = 0.762615; w = 0.00615385; h = 0.178615 } );
    ( "battle.menu_jpn.top",
      { x = 0.593239; y = 0.743878; w = 0.373344; h = 0.009360 } );
    ( "battle.menu_jpn.box_top",
      { x = 0.043001; y = 0.750564; w = 0.520015; h = 0.002674 } );
    ( "battle.menu_jpn.box_right",
      { x = 0.559460; y = 0.750564; w = 0.003556; h = 0.196556 } );
    ( "battle.player.left",
      { x = 0.577404; y = 0.504327; w = 0.001442; h = 0.121875 } );
    ( "battle.player.right",
      { x = 0.948558; y = 0.585096; w = 0.000481; h = 0.063462 } );
    ( "battle.player.top",
      { x = 0.594712; y = 0.481971; w = 0.325962; h = 0.002163 } );
    ( "battle.player.bottom",
      { x = 0.554808; y = 0.674519; w = 0.034615; h = 0.002163 } );
    ( "battle.player.background",
      { x = 0.552564; y = 0.583653; w = 0.414103; h = 0.009615 } );
    ( "battle.foe.left",
      { x = 0.067308; y = 0.140865; w = 0.001442; h = 0.090144 } );
    ( "battle.foe.right",
      { x = 0.422596; y = 0.132211; w = 0.000481; h = 0.054808 } );
    ( "battle.foe.top",
      { x = 0.085577; y = 0.119952; w = 0.329327; h = 0.000721 } );
    ( "battle.foe.bottom",
      { x = 0.109615; y = 0.264182; w = 0.328365; h = 0.001442 } );
    ( "battle.foe.background",
      { x = 0.050641; y = 0.126923; w = 0.388462; h = 0.063462 } );
    ( "battle.level_up.border_top",
      { x = 0.619231; y = 0.374038; w = 0.362179; h = 0.001923 } );
    ( "battle.level_up.border_right",
      { x = 0.982692; y = 0.376923; w = 0.001923; h = 0.597115 } );
    ( "battle.level_up.top",
      { x = 0.626282; y = 0.393492; w = 0.341026; h = 0.006175 } );
    ( "battle.level_up.right",
      { x = 0.967949; y = 0.401923; w = 0.003846; h = 0.550962 } );
    (* Measured on an mGBA double battle's move menu, in 240x160 pixels: the
       moves box's top rows (x 10-150, y 118-121), the PP box's (x 168-228),
       and the dark frame between them (x 158-161, y 112-157). *)
    ("battle.moves.top", { x = 0.041667; y = 0.7375; w = 0.583333; h = 0.01875 });
    ("battle.moves.pp_top", { x = 0.7; y = 0.7375; w = 0.25; h = 0.01875 });
    ( "battle.moves.divider",
      { x = 0.6625; y = 0.7375; w = 0.008333; h = 0.21875 } );
  ]

let probes = List.map (fun (id, b) -> Solid_color.probe ~id b) boxes
let holds = Solid_color.holds

(* The teal is dark, a channel sum near 230. Its hue test alone takes near
   white too (shares within 0.21 of the teal's): Pokemon Tower 5F's purified
   zone fades the overworld to white, and a frame of that fade read as the
   action menu (mGBA, 2026-11-23, run 1 of the mg-04 flee fix). *)
let teal_max_sum = 400.

let teal m id =
  holds m id (fun s ->
      Solid_color.sum s.mean <= teal_max_sum
      && Solid_color.is_solid ~ratio:box_teal ~max_distance:teal_distance
           ~max_stddev_sum:teal_stddev s)

let teal_box = teal
let white m id = holds m id (fun s -> Solid_color.is_white s)

let battle_text_box m =
  teal m "battle.box.top" && teal m "battle.box.right"
  && holds m "battle.box.line"
       (Solid_color.is_white ~max_stddev_sum:line_white_stddev)
  && holds m "battle.box.gold"
       (Solid_color.is_solid ~ratio:frame_gold ~max_distance:gold_distance
          ~max_stddev_sum:gold_stddev)

(* The Japanese menu's right edge is the other languages' one. *)
let menu_beside m ~prefix =
  white m (prefix ^ ".top")
  && white m "battle.menu.right"
  && teal m (prefix ^ ".box_top")
  && teal m (prefix ^ ".box_right")
  && not (white m (prefix ^ ".box_top"))

let battle_menu m =
  menu_beside m ~prefix:"battle.menu" || menu_beside m ~prefix:"battle.menu_jpn"

let edge m id ~light =
  let min_sum, max_sum =
    if light then (light_edge_min, light_edge_max)
    else (dark_edge_min, dark_edge_max)
  in
  holds m id (Solid_color.is_grey ~min_sum ~max_sum ~max_stddev_sum:edge_stddev)

let sand_or_white ~sand s =
  Solid_color.is_white s
  || Solid_color.is_solid ~ratio:sand ~max_distance:teal_distance
       ~max_stddev_sum:teal_stddev s

let plain_background m id ~sand =
  holds m id (fun s -> not (sand_or_white ~sand s))

let player_box m =
  edge m "battle.player.left" ~light:true
  && edge m "battle.player.right" ~light:false
  && edge m "battle.player.top" ~light:true
  && edge m "battle.player.bottom" ~light:false
  && plain_background m "battle.player.background" ~sand:player_sand

let foe_box m =
  edge m "battle.foe.left" ~light:true
  && edge m "battle.foe.right" ~light:true
  && edge m "battle.foe.top" ~light:true
  && edge m "battle.foe.bottom" ~light:false
  && plain_background m "battle.foe.background" ~sand:foe_sand

let hp_box m = player_box m || foe_box m

(* The slate is a mid grey, a channel sum near 375; like the teal, its hue
   test alone takes near white (the purified zone's fade read as a level-up
   box on the same run). *)
let slate_max_sum = 500.

let slate m id =
  holds m id (fun s ->
      Solid_color.sum s.mean <= slate_max_sum
      && Solid_color.is_solid ~ratio:level_up_slate ~max_distance:teal_distance
           ~max_stddev_sum:teal_stddev s)

let level_up_box m =
  slate m "battle.level_up.border_top"
  && slate m "battle.level_up.border_right"
  && white m "battle.level_up.top"
  && white m "battle.level_up.right"

let move_menu m =
  white m "battle.moves.top"
  && white m "battle.moves.pp_top"
  && holds m "battle.moves.divider" (fun s ->
         Solid_color.sum s.mean <= divider_max_sum
         && Solid_color.sum s.stddev <= divider_stddev)

let battle_shows m =
  battle_menu m || battle_text_box m || move_menu m || level_up_box m
  || hp_box m
