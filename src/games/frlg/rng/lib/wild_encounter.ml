(* Port of wild encounter generation (Pokemon/Pokemon_AdvRng.cpp). *)

type slot = { species : string; min_level : int; max_level : int }

type result = {
  species : string;
  pokemon : Pokemon_generation.result;
  slot : int;
  level : int;
}

let percent = 100

let slot_number_of_roll ~roll ~size ~super_rod =
  List.length
    (List.filter
       (fun t -> roll >= t)
       (Encounter_rates.thresholds ~size ~super_rod))

let contains text part =
  let n = String.length part in
  let rec at i =
    i + n <= String.length text && (String.sub text i n = part || at (i + 1))
  in
  at 0

let unown = "unown"
let form_exclamation = 26
let form_question = 27
let half_bits = 16

(* Forms a..z are 0..25, then '!' and '?'. *)
let unown_form_of_slot (slot : slot) =
  if not (contains slot.species unown) then None
  else
    match slot.species.[String.length slot.species - 1] with
    | 'a' .. 'z' as c -> Some (Char.code c - Char.code 'a')
    | '!' -> Some form_exclamation
    | '?' -> Some form_question
    | _ -> None

(* reroll_wild_pokemon and reroll_unown: draw PIDs two states at a time from
   [state] until [accept pid]; the IVs follow the accepted pair. *)
let reroll ~pid_of ~accept ~nature_of (state : Rng_state.t) start =
  let rec go low =
    let high = Lcg.next low in
    let pid = pid_of ~low ~high in
    if accept pid then
      let window =
        Rng_state.of_internal_state ~seed:state.seed ~advance:state.advance
          state.rng_method low
      in
      Pokemon_generation.pokemon_of_state_with_pid window ~pid
        ~nature:(nature_of pid)
    else go (Lcg.next high)
  in
  go start

let reroll_wild_pokemon nature state =
  reroll state state.Rng_state.s3 ~pid_of:Pokemon_generation.pid_of_states
    ~accept:(fun pid -> Pokemon_generation.nature_of_pid pid = nature)
    ~nature_of:(fun _ -> nature)

(* The C++ passes the pair swapped: the PID's high half comes from [low]. *)
let reroll_unown form state =
  reroll state state.Rng_state.s2
    ~pid_of:(fun ~low ~high ->
      Pokemon_generation.pid_of_states ~low:high ~high:low)
    ~accept:(fun pid -> Pokemon_generation.unown_form_of_pid pid = form)
    ~nature_of:Pokemon_generation.nature_of_pid

let pokemon_of_state (state : Rng_state.t) slots ~super_rod =
  let slot_roll = (state.s0 lsr half_bits) mod percent in
  let level_roll = state.s1 lsr half_bits in
  let nature = Pokemon_generation.nature_of_pid (state.s2 lsr half_bits) in
  let slot_num =
    slot_number_of_roll ~roll:slot_roll ~size:(Array.length slots) ~super_rod
  in
  let slot : slot = slots.(slot_num) in
  let diff = max 0 (slot.max_level - slot.min_level) in
  let level = slot.min_level + (level_roll mod (diff + 1)) in
  let pokemon =
    match unown_form_of_slot slot with
    | Some form -> reroll_unown form state
    | None -> reroll_wild_pokemon nature state
  in
  { species = slot.species; pokemon; slot = slot_num; level }

let base_species_slug species =
  if contains species unown then unown else species

let species_matches ~observed ~candidate =
  let base = base_species_slug observed in
  base = base_species_slug candidate
  && (observed = base || candidate = base || observed = candidate)
