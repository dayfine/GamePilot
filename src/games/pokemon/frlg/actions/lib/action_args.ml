module J = Json_field

type member = Species of string | Slot of int

let decode ~action read args =
  match read ~where:(action ^ ": ") args with
  | value -> Ok value
  | exception J.Invalid e ->
      Error (Pokemon_engine.Failure.cause ~repeats:true "bad_args" e)

let party_slots = 6

let slot ~where key args =
  let n = J.int ~where key args in
  if n < 1 || n > party_slots then
    J.fail "%s%s is %d, not a party slot (1-%d)." where key n party_slots
  else n

let role_species ~options ~where args role =
  match (Run_options.find options role, J.string_opt ~where "species" args) with
  | Some s, _ | None, Some s -> Some s
  | None, None ->
      J.fail "%srole %s needs --options %s=SPECIES or species." where role role

let species_opt ?(options = Run_options.none) ~where args =
  match J.string_opt ~where "role" args with
  | Some role -> role_species ~options ~where args role
  | None -> J.string_opt ~where "species" args

let member ?(options = Run_options.none) ~where args =
  match species_opt ~options ~where args with
  | Some species -> Species species
  | None when J.has "target_slot" args -> Slot (slot ~where "target_slot" args)
  | None -> J.fail "%sneeds species or target_slot." where

let member_to_string = function
  | Species s -> s
  | Slot n -> Printf.sprintf "slot %d" n

let member_keys =
  [ "species"; "sweeper"; "knock_off_species"; "recycle_species" ]

let named_species ~where args =
  List.filter_map (fun key -> J.string_opt ~where key args) member_keys

let field_move_users = [ ("cut_tree", "cut"); ("fly", "fly"); ("surf", "surf") ]

(* The badge each HM needs outside battle, by field move: pret pokefirered
   src/party_menu.c (FLAG_BADGE01_GET + the field move, from
   include/constants/party_menu.h: Flash 0 to Waterfall 6), the overworld
   prompts in data/scripts/field_moves.inc (Cut, Rock Smash, Strength) and
   src/field_control_avatar.c (Surf, Waterfall). *)
let field_move_badges =
  [
    ("flash", "boulder");
    ("cut", "cascade");
    ("fly", "thunder");
    ("strength", "rainbow");
    ("surf", "soul");
    ("rock_smash", "marsh");
    ("waterfall", "volcano");
  ]

let badge_needed action =
  Option.bind (List.assoc_opt action field_move_users) (fun m ->
      List.assoc_opt m field_move_badges)

let picks_member ~action args =
  action = "capture" || action = "pc_deposit"
  || (not (List.mem_assoc action field_move_users))
     && (J.has "role" args
        || List.exists (fun key -> J.has key args) member_keys)

let deposited_species ~where args =
  Option.fold ~none:[]
    ~some:(J.strings (where ^ "species"))
    (J.find "species" args)
