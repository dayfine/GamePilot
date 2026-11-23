module Names = Set.Make (String)

type t = { opened : Names.t; switches_on : Names.t }
type change = { newly_opened : Names.t; switches : (string * bool) list }

let new_game = { opened = Names.empty; switches_on = Names.empty }
let gate_key ~map ~gate = map ^ "/" ^ gate
let switch_on state id = Names.mem id state.switches_on

let apply state change =
  let set_switch on_set (id, on) =
    if on then Names.add id on_set else Names.remove id on_set
  in
  {
    opened = Names.union state.opened change.newly_opened;
    switches_on = List.fold_left set_switch state.switches_on change.switches;
  }

let change_between ~before ~after =
  let turned on ids = List.map (fun id -> (id, on)) (Names.elements ids) in
  let switches =
    turned true (Names.diff after.switches_on before.switches_on)
    @ turned false (Names.diff before.switches_on after.switches_on)
  in
  {
    newly_opened = Names.diff after.opened before.opened;
    switches = List.sort (fun (a, _) (b, _) -> String.compare a b) switches;
  }

let equal a b =
  Names.equal a.opened b.opened && Names.equal a.switches_on b.switches_on

let compare a b =
  match Names.compare a.opened b.opened with
  | 0 -> Names.compare a.switches_on b.switches_on
  | order -> order
