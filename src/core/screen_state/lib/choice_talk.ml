type look = { choice : bool; page : bool; past_choice : bool }
type move = Pick | Next_page | Answered | Wait

let move ~pressed look =
  if look.choice then Pick
  else if pressed && look.past_choice then Answered
  else if look.page then Next_page
  else Wait
