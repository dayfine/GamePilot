open Frlg_readers

type context = {
  stats : Effects.measurements -> bool;
  question : Effects.measurements -> bool;
  back : Effects.measurements -> bool;
}

(* The summary screen's moves page, where the move to forget is chosen. *)
let moves_page = 3
let probes = Battle_look.probes

let forget_list m =
  Summary_screen.page m = Some moves_page && Move_list_cursor.row m <> None

let evolution_question = Battle_yes_no.yes_no_box
let question c m = c.question m || evolution_question m

let classify c m : Level_up.look option =
  if forget_list m then Some Forget_list
  else if question c m then Some Move_prompt
  else if c.stats m then Some (Stats None)
  else if c.back m then Some Back
  else if Evolution_screen.evolution_shows m then Some (Evolving None)
  else None
