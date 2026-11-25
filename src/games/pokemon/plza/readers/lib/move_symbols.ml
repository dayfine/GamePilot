type symbol = No_effect | Not_very_effective | Effective | Super_effective

let symbol_name = function
  | No_effect -> "No Effect"
  | Not_very_effective -> "Not Very Effective"
  | Effective -> "Effective"
  | Super_effective -> "Super Effective"

let symbol_key = function
  | No_effect -> "no_effect"
  | Not_very_effective -> "not_very_effective"
  | Effective -> "effective"
  | Super_effective -> "super_effective"

let symbols = [ No_effect; Not_very_effective; Effective; Super_effective ]

let template (assets : Blob_assets.t) = function
  | No_effect -> assets.move_no_effect
  | Not_very_effective -> assets.move_not_very_effective
  | Effective -> assets.move_effective
  | Super_effective -> assets.move_super_effective

let box_width = 0.025
let box_height = 0.041

type corner = { left : float; top : float }

let box { left; top } =
  Native_box.of_fractions { left; top; width = box_width; height = box_height }

let boxes =
  [
    ("top", box { left = 0.780; top = 0.750 });
    ("left", box { left = 0.750; top = 0.800 });
    ("right", box { left = 0.806; top = 0.800 });
    ("bottom", box { left = 0.780; top = 0.850 });
  ]

let ranges =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0xffc0c0c0; max = 0xffffffff };
        { min = 0xffd0d0d0; max = 0xffffffff };
        { min = 0xffe0e0e0; max = 0xffffffff };
        { min = 0xfff0f0f0; max = 0xffffffff };
      ]

let min_area = 50.
let max_score = 150.

let id slot symbol =
  Printf.sprintf "move_symbols.%s.%s" slot (symbol_key symbol)

let symbol_probe ~picture ~assets (slot, area) symbol =
  Find_probe.probe ~template:(template assets symbol) ~picture
    ~id:(id slot symbol) area
    (Wire.Blob_find.params ~filters:ranges ~min_area ())

let probes ~picture ~assets =
  List.concat_map
    (fun box -> List.concat_map (symbol_probe ~picture ~assets box) symbols)
    boxes

(* The symbol's best score in the slot. *)
let best_score m slot symbol =
  List.fold_left
    (fun best (b : Wire.Blob_find.blob) ->
      match b.score with Some s when s < best -> s | _ -> best)
    Float.infinity
    (Find_probe.read m (id slot symbol))

let read_slot m (slot, _) =
  let scored = List.map (fun s -> (best_score m slot s, s)) symbols in
  let score, symbol =
    List.fold_left
      (fun (bs, bsym) (s, sym) -> if s < bs then (s, sym) else (bs, bsym))
      (Float.infinity, No_effect)
      scored
  in
  if score <= max_score then Some symbol else None

let read m = List.map (read_slot m) boxes
