type replacing = Named of string | Slot of int
type move_rule = { learn : string; replacing : replacing }
type policy = { rules : move_rule list; evolve : bool }

type t = {
  by_slot : (int * policy) list;
  by_species : (string * policy) list;
  default : policy;
}

let for_everyone policy = { by_slot = []; by_species = []; default = policy }
let decline_all = { rules = []; evolve = false }

let for_member t ~slot ~species =
  match List.assoc_opt slot t.by_slot with
  | Some p -> p
  | None ->
      Option.value (List.assoc_opt species t.by_species) ~default:t.default

let rule_for rules ~offered = List.find_opt (fun r -> r.learn = offered) rules

let describe_rule r =
  match r.replacing with
  | Named m -> r.learn ^ " over " ^ m
  | Slot s -> Printf.sprintf "%s over move %d" r.learn s
