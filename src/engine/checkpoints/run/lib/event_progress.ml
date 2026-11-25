type 'reason t = Started | Passed | Skipped of string | Failed of 'reason

let map f = function
  | Started -> Started
  | Passed -> Passed
  | Skipped flag -> Skipped flag
  | Failed reason -> Failed (f reason)
