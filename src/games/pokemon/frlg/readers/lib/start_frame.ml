let columns = 15
let rows = 10
let id i = Printf.sprintf "start_frame.%d" i

let box i : Wire.box =
  let w = 1. /. float_of_int columns and h = 1. /. float_of_int rows in
  {
    x = float_of_int (i mod columns) *. w;
    y = float_of_int (i / columns) *. h;
    w;
    h;
  }

let count = columns * rows
let probes = List.init count (fun i -> Solid_color.probe ~id:(id i) (box i))

type t = Wire.rgb array

let read m =
  let tiles = Array.init count (fun i -> Solid_color.read m (id i)) in
  if Array.for_all Option.is_some tiles then
    Some (Array.map (fun s -> (Option.get s).Solid_color.mean) tiles)
  else None

type difference = { tiles : int; changed : int }

let tile_change = 24.
let most_changed_percent = 25
let channels = 3.

let channel_difference (a : Wire.rgb) (b : Wire.rgb) =
  (Float.abs (a.r -. b.r) +. Float.abs (a.g -. b.g) +. Float.abs (a.b -. b.b))
  /. channels

let compare ~reference frame =
  let changed = ref 0 in
  Array.iteri
    (fun i a ->
      if i < Array.length frame && channel_difference a frame.(i) > tile_change
      then incr changed)
    reference;
  { tiles = Array.length reference; changed = !changed }

let percent = 100

let same_place d =
  d.tiles > 0 && d.changed * percent <= most_changed_percent * d.tiles

let difference_to_string d =
  Printf.sprintf "%d of %d tiles changed" d.changed d.tiles

let tile_json (c : Wire.rgb) = `List [ `Float c.r; `Float c.g; `Float c.b ]

let to_json t =
  `Assoc [ ("tiles", `List (List.map tile_json (Array.to_list t))) ]

let number = function
  | `Float f -> Some f
  | `Int i -> Some (float_of_int i)
  | _ -> None

let tile = function
  | `List [ r; g; b ] -> (
      match (number r, number g, number b) with
      | Some r, Some g, Some b -> Some { Wire.r; g; b }
      | _ -> None)
  | _ -> None

let tiles_of l =
  let tiles = List.filter_map tile l in
  if List.length tiles = count then Ok (Array.of_list tiles)
  else Error (Printf.sprintf "not %d tiles of [r, g, b]" count)

let of_json json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "tiles" fields with
      | Some (`List l) -> tiles_of l
      | _ -> Error "no \"tiles\" list")
  | _ -> Error "not an object"
