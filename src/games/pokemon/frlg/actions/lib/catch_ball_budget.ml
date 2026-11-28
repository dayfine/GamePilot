type catch_mode = Throw_only | Weakened_asleep

type formula_params = {
  full_hp_divisor : float;
  max_modified_rate : float;
  shake_numerator : float;
  shake_dividend : float;
  shake_divisor : float;
  shake_checks : float;
  target_probability : float;
  min_balls : int;
  max_balls : int;
}

(* Gen 3 (pokefirered src/battle_script_commands.c, Cmd_handleballthrow)
   capture formula constants and [5, 99] budget clamp at 99% cumulative catch
   probability. *)
let params =
  {
    full_hp_divisor = 3.0;
    max_modified_rate = 255.0;
    shake_numerator = 1048560.0;
    shake_dividend = 16711680.0;
    shake_divisor = 65536.0;
    shake_checks = 4.0;
    target_probability = 0.99;
    min_balls = 5;
    max_balls = 99;
  }

type ball_bonuses = { standard : float; great : float; ultra : float }

let bonuses = { standard = 1.0; great = 1.5; ultra = 2.0 }

type mode_factors = { hp_factor : float; status_multiplier : float }

let throw_only_factors =
  { hp_factor = 1.0 /. params.full_hp_divisor; status_multiplier = 1.0 }

let weakened_asleep_factors = { hp_factor = 1.0; status_multiplier = 2.0 }

type rate_tier = { rate : int; names : string }

(* Gen 3 base catch rates from pokefirered src/data/pokemon/base_stats.h for
   all FRLG wild encounter species and static legendaries. *)
let species_tiers =
  [
    {
      rate = 255;
      names =
        "bellsprout caterpie diglett ekans geodude hoppip ledyba magikarp \
         meowth nidoran-f nidoran-m oddish pidgey poliwag rattata sandshrew \
         sentret spearow spinarak weedle wooper zubat";
    };
    { rate = 225; names = "goldeen horsea krabby staryu swinub unown" };
    { rate = 200; names = "abra" };
    {
      rate = 190;
      names =
        "cubone doduo drowzee dunsparce gastly grimer growlithe koffing \
         magnemite mankey marill natu paras pikachu ponyta psyduck remoraid \
         seel shellder slowpoke slugma tentacool venonat voltorb vulpix";
    };
    { rate = 180; names = "machop" };
    { rate = 170; names = "jigglypuff" };
    { rate = 150; names = "clefairy" };
    { rate = 127; names = "raticate" };
    {
      rate = 120;
      names =
        "gloom graveler kakuna metapod nidorina nidorino phanpy pidgeotto \
         poliwhirl rhyhorn weepinbell";
    };
    { rate = 100; names = "kadabra" };
    {
      rate = 90;
      names = "arbok exeggcute fearow golbat haunter machoke persian sandslash";
    };
    {
      rate = 75;
      names =
        "dewgong golduck hypno magcargo marowak muk parasect primeape seadra \
         seaking slowbro venomoth yanma";
    };
    {
      rate = 60;
      names = "electrode kingler magneton rapidash sneasel tentacruel weezing";
    };
    { rate = 50; names = "dugtrio" };
    {
      rate = 45;
      names =
        "aerodactyl blastoise bulbasaur charizard charmander charmeleon \
         delibird dragonair dratini eevee electabuzz farfetchd gyarados \
         heracross hitmonchan hitmonlee ivysaur jynx kabuto kangaskhan lapras \
         larvitar lickitung magmar misdreavus mr-mime omanyte onix pinsir \
         porygon qwilfish scyther squirtle tangela tauros venusaur wartortle \
         wobbuffet";
    };
    { rate = 35; names = "ditto" };
    { rate = 30; names = "chansey murkrow" };
    { rate = 25; names = "mantine skarmory snorlax" };
    {
      rate = 3;
      names =
        "articuno deoxys entei ho-oh lugia mewtwo moltres raikou suicune zapdos";
    };
  ]

let parsed_tiers =
  List.map
    (fun tier -> (tier.rate, String.split_on_char ' ' tier.names))
    species_tiers

let normalize_species slug =
  let lower = String.lowercase_ascii (String.trim slug) in
  if String.starts_with ~prefix:"unown-" lower then "unown" else lower

let catch_rate slug =
  let key = normalize_species slug in
  let match_tier (rate, names) =
    if List.mem key names then Some rate else None
  in
  List.find_map match_tier parsed_tiers

let ball_multiplier = function
  | "poke-ball" | "luxury-ball" -> Some bonuses.standard
  | "great-ball" -> Some bonuses.great
  | "ultra-ball" -> Some bonuses.ultra
  | _ -> None

let mode_factors = function
  | Throw_only -> throw_only_factors
  | Weakened_asleep -> weakened_asleep_factors

let single_throw_probability ~catch_rate ~ball_mult ~mode =
  let f = mode_factors mode in
  let modified =
    f.hp_factor *. float_of_int catch_rate *. ball_mult *. f.status_multiplier
  in
  if modified >= params.max_modified_rate then 1.0
  else
    let a = Float.max 1.0 (Float.floor modified) in
    let root = sqrt (sqrt (params.shake_dividend /. a)) in
    let b = Float.floor (params.shake_numerator /. root) in
    (b /. params.shake_divisor) ** params.shake_checks

let catch_probability ~catch_rate ~ball ~mode =
  if catch_rate < 1 then None
  else if ball = "master-ball" then Some 1.0
  else
    Option.map
      (fun ball_mult -> single_throw_probability ~catch_rate ~ball_mult ~mode)
      (ball_multiplier ball)

let clamp_balls n = Int.max params.min_balls (Int.min params.max_balls n)

let balls_for_probability p =
  if p >= 1.0 then params.min_balls
  else
    let numerator = log (1.0 -. params.target_probability) in
    let denominator = log (1.0 -. p) in
    clamp_balls (int_of_float (Float.ceil (numerator /. denominator)))

let balls_for_rate ~catch_rate ~ball ~mode =
  if catch_rate < 1 then None
  else if ball = "master-ball" then Some 1
  else
    Option.map balls_for_probability (catch_probability ~catch_rate ~ball ~mode)

let required ~species ~ball ~mode =
  if ball = "master-ball" then Some 1
  else
    Option.bind (catch_rate species) (fun cr ->
        balls_for_rate ~catch_rate:cr ~ball ~mode)

let catch_mode_of_string = function
  | Some ("phase1" | "phase2") -> Weakened_asleep
  | _ -> Throw_only
