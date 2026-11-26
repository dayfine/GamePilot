module C = Plza_gift_catalog.Gift_catalog
module M = Pokemon_home.Box_moves
module B = Pokemon_home.Box_view

let order : C.home_order -> B.order = function
  | Left_to_right -> Left_to_right
  | Right_to_left -> Right_to_left

let move (g : C.gift) (p : C.pokemon) : (M.t, string) result =
  if p.box_slot.box <> 1 || p.box_slot.slot > B.columns then
    Error
      (Printf.sprintf "%s: Box %d slot %d is not in Box 1's first row (1 to %d)"
         g.id p.box_slot.box p.box_slot.slot B.columns)
  else
    Ok
      {
        name = g.name;
        game_col = p.box_slot.slot - 1;
        boxes = p.home_boxes;
        order = order p.home_order;
      }

let of_catalog (catalog : C.t) =
  let moves =
    List.filter_map (fun (g : C.gift) -> Option.map (move g) g.pokemon) catalog
  in
  match moves with
  | [] -> Error "the gift catalog has no Pokémon to move"
  | moves ->
      List.fold_right
        (fun m acc -> Result.bind m (fun m -> Result.map (List.cons m) acc))
        moves (Ok [])
