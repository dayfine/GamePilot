module C = Plza_gift_catalog.Gift_catalog
module M = Pokemon_home.Box_moves
module B = Pokemon_home.Box_view

type t = { moves : M.t list; skipped : string list }

let slots_per_box = B.columns * B.slot_rows

let move (g : C.gift) (p : C.pokemon) : (M.t, string) result =
  let slot = p.box_slot.slot in
  if p.box_slot.box <> 1 || slot < 1 || slot > slots_per_box then
    Error
      (Printf.sprintf "%s: Box %d slot %d is not in Box 1 (slots 1 to %d)" g.id
         p.box_slot.box slot slots_per_box)
  else
    let index = slot - 1 in
    Ok
      {
        name = g.name;
        source = { box = 1; row = index / B.columns; col = index mod B.columns };
        destination =
          { boxes = p.home_boxes; fallback = []; order = p.home_order };
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
