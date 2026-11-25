type t = string list

let of_list species =
  if List.length species > Action_args.party_slots then
    invalid_arg "Party_roster.of_list: more than six members"
  else species

let of_read species = of_list (List.map (Option.value ~default:"?") species)

let of_string text =
  String.split_on_char ',' text
  |> List.map String.trim
  |> List.filter (fun s -> s <> "")
  |> of_list

let to_list t = t
let size = List.length

let slot_of t species =
  List.find_map Fun.id
    (List.mapi (fun i s -> if s = species then Some (i + 1) else None) t)

let resolve t (member : Action_args.member) =
  match member with
  | Slot n -> Ok n
  | Species s ->
      let missing = s ^ " is not in the party (" ^ String.concat ", " t ^ ")" in
      Option.to_result
        ~none:(Checkpoints.Failure.cause ~repeats:true "not_in_party" missing)
        (slot_of t s)

let swap t a b =
  let at i = List.nth_opt t (i - 1) in
  List.mapi
    (fun i s ->
      if i + 1 = a then Option.value (at b) ~default:s
      else if i + 1 = b then Option.value (at a) ~default:s
      else s)
    t

let replace t ~slot species =
  List.mapi (fun i s -> if i + 1 = slot then species else s) t

let add t species =
  if size t >= Action_args.party_slots then t else t @ [ species ]

let remove t species =
  match slot_of t species with
  | None -> t
  | Some slot -> of_list (List.filteri (fun i _ -> i + 1 <> slot) (to_list t))
