module J = Grid_maps.Json_field

type member = Species of string | Slot of int

let decode ~action read args =
  match read ~where:(action ^ ": ") args with
  | value -> Ok value
  | exception J.Invalid e ->
      Error (Story.Failure.cause ~repeats:true "bad_args" e)

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
