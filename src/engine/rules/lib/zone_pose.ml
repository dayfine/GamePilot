type t = { place : string; spot : string option }
type observed = t

let matches pose observed =
  pose.place = observed.place && (pose.spot = None || pose.spot = observed.spot)

let to_string { place; spot } =
  match spot with Some s -> place ^ "/" ^ s | None -> place

let observed_to_string = to_string
