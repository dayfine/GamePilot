type t = { place : string; spot : string option }
type observed = t

let matches pose observed =
  pose.place = observed.place && (pose.spot = None || pose.spot = observed.spot)
