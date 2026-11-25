module J = Json_field

type member = Species of string | Slot of int

let decode ~action read args =
  match read ~where:(action ^ ": ") args with
  | value -> Ok value
  | exception J.Invalid e ->
      Error (Pokemon_checkpoints.Failure.cause ~repeats:true "bad_args" e)

let party_slots = 6

let slot ~where key args =
  let n = J.int ~where key args in
  if n < 1 || n > party_slots then
    J.fail "%s%s is %d, not a party slot (1-%d)." where key n party_slots
  else n

let member ~where args =
  match J.string_opt ~where "species" args with
  | Some species -> Species species
  | None when J.has "target_slot" args -> Slot (slot ~where "target_slot" args)
  | None -> J.fail "%sneeds species or target_slot." where

let member_to_string = function
  | Species s -> s
  | Slot n -> Printf.sprintf "slot %d" n

let member_keys =
  [ "species"; "sweeper"; "knock_off_species"; "recycle_species" ]

let field_move_users = [ ("cut_tree", "cut") ]

let picks_member ~action args =
  (not (List.mem_assoc action field_move_users))
  && List.exists (fun key -> J.has key args) member_keys

let deposited_species ~where args =
  Option.fold ~none:[]
    ~some:(J.strings (where ^ "species"))
    (J.find "species" args)
