type shiny = Not_shiny | Star | Square

let shiny_name = function
  | Not_shiny -> "Not Shiny"
  | Star -> "Star Shiny"
  | Square -> "Square Shiny"

type gender = Male | Female | Genderless

let gender_name = function
  | Male -> "Male"
  | Female -> "Female"
  | Genderless -> "Genderless"

type 'a per_stat = {
  hp : 'a;
  attack : 'a;
  defense : 'a;
  spatk : 'a;
  spdef : 'a;
  speed : 'a;
}

type base_stats = int per_stat

type ivs = {
  hp : int;
  attack : int;
  defense : int;
  spatk : int;
  spdef : int;
  speed : int;
}

let ivs_to_string i =
  [ i.hp; i.attack; i.defense; i.spatk; i.spdef; i.speed ]
  |> List.map string_of_int |> String.concat "/"

type pokemon = {
  ec : int;
  pid : int;
  shiny : shiny;
  ivs : ivs;
  ability : int;
  gender : gender;
  nature : int;
  level : int;
  height : int;
  weight : int;
}

let natures =
  [|
    "Hardy"; "Lonely"; "Brave"; "Adamant"; "Naughty";
    "Bold"; "Docile"; "Relaxed"; "Impish"; "Lax";
    "Timid"; "Hasty"; "Serious"; "Jolly"; "Naive";
    "Modest"; "Mild"; "Quiet"; "Bashful"; "Rash";
    "Calm"; "Gentle"; "Sassy"; "Careful"; "Quirky";
  |]
[@@ocamlformat "disable"]

let nature_name nature =
  if nature >= 0 && nature < Array.length natures then natures.(nature) else "?"

let half_mask = 0xFFFF
let half_bits = 16
let star_limit = 16
let psv pid = (pid lsr half_bits) lxor (pid land half_mask)

let shiny_of_pid ~pid ~tsv =
  let psv = psv pid in
  if psv = tsv then Square
  else if tsv lxor psv < star_limit then Star
  else Not_shiny

let is_shiny ~pid ~tsv = tsv lxor psv pid < star_limit

type template = {
  species : string;
  level : int;
  guaranteed_ivs : int;
  ability_kind : int;
  gender_ratio : int;
  shiny_locked : bool;
}

(* The PID bit flipped to make a shiny PID not shiny. *)
let unshiny_bit = 0x1000_0000

let force_not_shiny pid ~tsv =
  if is_shiny ~pid ~tsv then pid lxor unshiny_bit else pid

(* The XOR between PSV and TSV that each kind of shiny is forced to. *)
let forced_xor = function Square -> 0 | Star -> 1 | Not_shiny -> 2

let force_shiny pid ~tsv shiny =
  if shiny_of_pid ~pid ~tsv = shiny then pid
  else
    let low = pid land half_mask in
    let high = low lxor tsv lxor forced_xor shiny land half_mask in
    (high lsl half_bits) lor low

(* The PID re-rolled for this trainer: shiny (of the same kind) for exactly the
   rolls that were shiny for the generated trainer id [sidtid]. *)
let resolve_unlocked_shiny pid ~sidtid ~tsv =
  let shiny = shiny_of_pid ~pid ~tsv:(psv sidtid) in
  if shiny <> Not_shiny then (force_shiny pid ~tsv shiny, shiny)
  else (force_not_shiny pid ~tsv, shiny)

let resolve_shiny pid ~sidtid ~tsv ~shiny_locked =
  if shiny_locked then (force_not_shiny pid ~tsv, Not_shiny)
  else resolve_unlocked_shiny pid ~sidtid ~tsv

(* Where the rolls come from: one generator stepped per roll, or the search's
   window of outputs. *)
type source = { next : unit -> int }

let roll source modulo = source.next () mod modulo
let stat_count = 6
let perfect_iv = 31
let iv_values = 32
let unset_iv = -1

let roll_ivs source tmpl =
  let ivs = Array.make stat_count unset_iv in
  let placed = ref 0 in
  while !placed < tmpl.guaranteed_ivs do
    let index = roll source stat_count in
    if ivs.(index) = unset_iv then (
      ivs.(index) <- perfect_iv;
      incr placed)
  done;
  let fill iv = if iv = unset_iv then roll source iv_values else iv in
  (* In stat order: each unset IV takes the next roll. *)
  Array.iteri (fun c iv -> ivs.(c) <- fill iv) ivs;
  {
    hp = ivs.(0);
    attack = ivs.(1);
    defense = ivs.(2);
    spatk = ivs.(3);
    spdef = ivs.(4);
    speed = ivs.(5);
  }

let hidden_ability = 2
let ability_choices = 2

let roll_ability source tmpl =
  match tmpl.ability_kind with
  | (0 | 1) as fixed -> fixed
  | 2 ->
      (* Hidden ability: the roll still happens, its value is ignored. *)
      ignore (source.next ());
      hidden_ability
  | _ -> roll source ability_choices

let gender_roll_range = 253

let roll_gender source tmpl =
  match tmpl.gender_ratio with
  | 255 -> Genderless
  | 254 -> Female
  | 0 -> Male
  | ratio -> if roll source gender_roll_range + 1 < ratio then Female else Male

let nature_count = 25
let size_first_roll = 129
let size_second_roll = 128

let roll_size source =
  let first = roll source size_first_roll in
  first + roll source size_second_roll

(* generate_static_impl: every roll in the game's order. *)
let generate_from source tmpl ~tsv ~synchronize_nature =
  let ec = source.next () in
  let sidtid = source.next () in
  let pid, shiny =
    resolve_shiny (source.next ()) ~sidtid ~tsv ~shiny_locked:tmpl.shiny_locked
  in
  let ivs = roll_ivs source tmpl in
  let ability = roll_ability source tmpl in
  let gender = roll_gender source tmpl in
  (* A Synchronize lead skips the nature roll, shifting every roll after it. *)
  let nature =
    match synchronize_nature with
    | Some nature -> nature
    | None -> roll source nature_count
  in
  let height = roll_size source in
  let weight = roll_size source in
  {
    ec;
    pid;
    shiny;
    ivs;
    ability;
    gender;
    nature;
    level = tmpl.level;
    height;
    weight;
  }

let direct_source rng =
  { next = (fun () -> Xorshift128.bdsp_gen_transform (Xorshift128.next rng)) }

let generate state tmpl ~tsv ~synchronize_nature =
  generate_from
    (direct_source (Xorshift128.create state))
    tmpl ~tsv ~synchronize_nature

type hit = { advances : int; state : Xorshift128.state; pokemon : pokemon }

type searcher = {
  base_state : Xorshift128.state;
  template : template;
  tsv : int;
  synchronize_nature : int option;
}

let searcher base_state template ~tsv ~synchronize_nature =
  { base_state; template; tsv; synchronize_nature }

let generate_at s advances =
  let rng = Xorshift128.create s.base_state in
  Xorshift128.advance rng advances;
  generate (Xorshift128.state rng) s.template ~tsv:s.tsv
    ~synchronize_nature:s.synchronize_nature

(* [STATIC_SEARCH_WINDOW]: 64 outputs. *)
let search_window_bits = 6

let scan ?(stop_at_first = false) s ~min_advances ~max_advances ~accept =
  (* Tracks the state at the start of each advance so that a hit can report it. *)
  let rng = Xorshift128.create s.base_state in
  Xorshift128.advance rng min_advances;
  let window = Xorshift128.Window.create ~size_bits:search_window_bits rng in
  let source = { next = (fun () -> Xorshift128.Window.next_gen window) } in
  let rec walk advances hits =
    if advances > max_advances then hits
    else
      let pokemon =
        generate_from source s.template ~tsv:s.tsv
          ~synchronize_nature:s.synchronize_nature
      in
      let found = accept pokemon in
      let hits =
        if found then
          { advances; state = Xorshift128.state rng; pokemon } :: hits
        else hits
      in
      if found && stop_at_first then hits
      else (
        ignore (Xorshift128.next rng);
        Xorshift128.Window.advance_state window;
        walk (advances + 1) hits)
  in
  List.rev (walk min_advances [])
