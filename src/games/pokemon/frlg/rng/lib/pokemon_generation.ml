(* Port of Method 1/2/4 generation (Pokemon/Pokemon_AdvRng.cpp). *)

type ivs = {
  hp : int;
  attack : int;
  defense : int;
  spatk : int;
  spdef : int;
  speed : int;
}

type result = {
  pid : int;
  gender_value : int;
  nature : int;
  ability : int;
  ivs : ivs;
}

type gender = Male | Female
type shiny_type = Normal | Star | Square

let natures = 25
let iv_bits = 5
let iv_mask = 0x1f
let byte_mask = 0xff
let half_mask = 0xffff
let star_limit = 8
let half_bits = 16
let high_half_mask = 0xffff0000
let unown_forms = 28
let low_two_bits = 0x3
let pid_bytes = 4
let bits_per_byte = 8
let pid_of_states ~low ~high = (high land high_half_mask) + (low lsr half_bits)
let nature_of_pid pid = pid mod natures
let ability_of_pid pid = pid land 1

(* Below -1 means genderless. *)
let gender_of_value value ~threshold =
  if threshold < -1 then None
  else if value <= threshold then Some Female
  else Some Male

(* The low two bits of each PID byte, highest byte first, mod 28. *)
let unown_form_of_pid pid =
  List.init pid_bytes (fun i -> pid_bytes - 1 - i)
  |> List.fold_left
       (fun acc byte ->
         (acc lsl 2) lor ((pid lsr (bits_per_byte * byte)) land low_two_bits))
       0
  |> fun bits -> bits mod unown_forms

(* iv_group_from_state: three 5-bit IVs from the state's high half. *)
let iv_group ?(roaming = false) state =
  let bits = state lsr half_bits in
  let bits = if roaming then bits land byte_mask else bits in
  ( bits land iv_mask,
    (bits lsr iv_bits) land iv_mask,
    (bits lsr (2 * iv_bits)) land iv_mask )

let iv_groups ~roaming (state : Rng_state.t) =
  if roaming then (iv_group ~roaming state.s2, (0, 0, 0))
  else
    match state.rng_method with
    | Method2 -> (iv_group state.s3, iv_group state.s4)
    | Method4 -> (iv_group state.s2, iv_group state.s4)
    | Method1 | Method3 | Any -> (iv_group state.s2, iv_group state.s3)

let pokemon_of_state_with_pid ?(roaming = false) state ~pid ~nature =
  let (hp, attack, defense), (speed, spatk, spdef) = iv_groups ~roaming state in
  {
    pid;
    gender_value = pid land byte_mask;
    nature;
    ability = ability_of_pid pid;
    ivs = { hp; attack; defense; spatk; spdef; speed };
  }

let pokemon_of_state ?roaming (state : Rng_state.t) =
  let pid = pid_of_states ~low:state.s0 ~high:state.s1 in
  pokemon_of_state_with_pid ?roaming state ~pid ~nature:(nature_of_pid pid)

let shiny_type_of_pid pid ~tid_xor_sid =
  let pid_xor = (pid lsr half_bits) lxor (pid land half_mask) in
  if pid_xor = tid_xor_sid then Square
  else if pid_xor lxor tid_xor_sid < star_limit then Star
  else Normal
