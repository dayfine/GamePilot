module C = Plza_gift_catalog.Gift_catalog
module M = Pokemon_home.Box_moves
module B = Pokemon_home.Box_view

type t = { moves : M.t list; skipped : string list }

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
        order = p.home_order;
      }

let all_ok results =
  List.fold_right
    (fun m acc -> Result.bind m (fun m -> Result.map (List.cons m) acc))
    results (Ok [])

let moves_of gifts =
  all_ok
    (List.filter_map (fun (g : C.gift) -> Option.map (move g) g.pokemon) gifts)

let of_catalog ~today (catalog : C.t) =
  let pokemon = List.filter (fun (g : C.gift) -> g.pokemon <> None) catalog in
  let expired, live = List.partition (C.expired ~today) pokemon in
  let skipped = List.map C.skipped_line expired in
  match live with
  | [] when pokemon = [] -> Error "the gift catalog has no Pokémon to move"
  | [] ->
      Error
        ("every Pokémon gift of the catalog has expired, nothing to move: "
       ^ String.concat " " skipped)
  | live -> Result.map (fun moves -> { moves; skipped }) (moves_of live)
