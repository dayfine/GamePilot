type t =
  | Wall
  | Open
  | Tall_grass
  | Water
  | Ledge of Direction.t
  | Door
  | Sign
  | Outside
  | Closed_side of Direction.t
  | Spin of Direction.t
  | Stop_spin
  | Fall_hole
  | Strength_button
  | Ice
  | Thin_ice
  | Gate

let table =
  [
    ('#', Wall);
    ('.', Open);
    ('~', Tall_grass);
    ('w', Water);
    ('^', Ledge North);
    ('v', Ledge South);
    ('<', Ledge West);
    ('>', Ledge East);
    ('D', Door);
    ('S', Sign);
    (' ', Outside);
    ('8', Closed_side North);
    ('2', Closed_side South);
    ('4', Closed_side West);
    ('6', Closed_side East);
    ('u', Spin North);
    ('d', Spin South);
    ('l', Spin West);
    ('r', Spin East);
    ('o', Stop_spin);
    ('H', Fall_hole);
    ('B', Strength_button);
    ('i', Ice);
    ('I', Thin_ice);
    ('G', Gate);
  ]

let of_glyph glyph = List.assoc_opt glyph table
let glyph tile = fst (List.find (fun (_, known) -> known = tile) table)
let glyphs = String.of_seq (List.to_seq (List.map fst table))
