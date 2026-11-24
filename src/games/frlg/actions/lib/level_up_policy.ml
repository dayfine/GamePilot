type move_rule = { learn : string; replacing : string }
type policy = { rules : move_rule list; evolve : bool }

type t = {
  by_slot : (int * policy) list;
  by_species : (string * policy) list;
  default : policy;
}

let only policy = { by_slot = []; by_species = []; default = policy }
let decline_all = { rules = []; evolve = false }

let for_member t ~slot ~species =
  match List.assoc_opt slot t.by_slot with
  | Some p -> p
  | None ->
      Option.value (List.assoc_opt species t.by_species) ~default:t.default

let rule_for rules ~offered = List.find_opt (fun r -> r.learn = offered) rules
let describe_rule r = r.learn ^ " over " ^ r.replacing
