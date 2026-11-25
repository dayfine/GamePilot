type t = Started | Passed | Skipped of string | Failed of string

let to_watch = function
  | Started -> (Wire.Watch.Current, "")
  | Passed -> (Wire.Watch.Done, "")
  | Skipped flag -> (Wire.Watch.Skipped, flag)
  | Failed reason -> (Wire.Watch.Failed, reason)
