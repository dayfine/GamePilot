let frame_height = 1080.
let window_top = 206.
let window_height = 72.

let window : Wire.box =
  {
    x = 0.;
    y = window_top /. frame_height;
    w = 1.;
    h = window_height /. frame_height;
  }

let cyan_red_max = 120
let cyan_green_min = 150
let cyan_blue_min = 200
let channel_max = 255

let cyan : Wire.color_range =
  {
    min = (0, cyan_green_min, cyan_blue_min);
    max = (cyan_red_max, channel_max, channel_max);
  }

let probe id template =
  Wire.template_match_probe ~ink:cyan ~id ~box:window ~delivery:Every ~template
    ()

let score m id =
  match Effects.probe m id with
  | Some (Wire.Template_match { score; _ }) -> Some score
  | _ -> None

let max_score = 0.08

let shows m id =
  Option.fold ~none:false ~some:(fun s -> s <= max_score) (score m id)

type game_steps = {
  title_shows : unit -> bool;
  press : Timed_press.t -> unit;
  log : string -> unit;
}

type walk = { first : Timed_press.t; next : Timed_press.t; tiles : int }

let not_found ~name tiles =
  Printf.sprintf "%s's tile is not among the first %d on HOME" name tiles

let find_tile steps walk ~name =
  let rec from k =
    if steps.title_shows () then (
      steps.log (Printf.sprintf "%s is tile %d." name (k + 1));
      Ok k)
    else if k + 1 >= walk.tiles then Error (not_found ~name walk.tiles)
    else (
      steps.press walk.next;
      from (k + 1))
  in
  steps.press walk.first;
  from 0
