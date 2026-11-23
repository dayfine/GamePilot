let npc_tick_seconds = 1.017
let pokemon_blink_min_seconds = 3.0
let pokemon_blink_max_seconds = 12.0
let pokemon_blink_offset_seconds = 0.285

type blink_type = Single | Double

let blink_type_name = function Single -> "Single" | Double -> "Double"
let npc_blink_bits = 0x0e
let npc_blinks roll = roll land npc_blink_bits = 0
let npc_blink_type roll = if roll land 1 = 0 then Single else Double

(* The fraction is 23 bits over 2^23 - 1. *)
let fraction_bits = 23
let fraction_scale = 8388607.0
let fraction_mask = 0x7f_ffff

(* Longest and shortest gap the game can produce, and the span between them. *)
let longest_seconds = pokemon_blink_max_seconds +. pokemon_blink_offset_seconds
let span_seconds = pokemon_blink_max_seconds -. pokemon_blink_min_seconds

(* A product rounded on its own. ocamlopt's arm64 backend would otherwise fuse
   it with the following add into one FMA, which rounds once and differs from
   the C++ (and from OCaml on x86) by one ulp. *)
let rounded_product a b = Sys.opaque_identity (a *. b)

let range_float roll ~minimum ~maximum =
  (* 23 bits of mantissa divided by 2^23 - 1, not 2^23. *)
  let fraction = float_of_int (roll land fraction_mask) /. fraction_scale in
  rounded_product fraction minimum +. rounded_product (1.0 -. fraction) maximum

let pokemon_blink_interval roll =
  range_float roll ~minimum:pokemon_blink_min_seconds
    ~maximum:pokemon_blink_max_seconds
  +. pokemon_blink_offset_seconds

(* The two extreme intervals are not exactly representable. *)
let slack = 1e-9

let pokemon_blink_fraction interval_seconds =
  (* range_float runs backwards, so a longer gap means a smaller fraction. *)
  let scaled = (longest_seconds -. interval_seconds) /. span_seconds in
  (* NaN is rejected rather than sliding through. *)
  if (not (scaled >= -.slack)) || scaled > 1.0 +. slack then None
  else
    let scaled = if scaled < 0.0 then 0.0 else scaled in
    let value = scaled *. fraction_scale in
    Some
      (if value >= float_of_int fraction_mask then fraction_mask
       else int_of_float value)

let pokemon_blink_known_bits = 4
let bucket_shift = fraction_bits - pokemon_blink_known_bits
let bucket_width = 1 lsl bucket_shift

let margin_seconds interval_seconds fraction bucket =
  (* Distance to whichever end of the bucket is nearer, converted from fraction
     units back into seconds of timing error. *)
  let into_bucket = fraction - (bucket lsl bucket_shift) in
  let to_next = bucket_width - into_bucket in
  let nearest = if into_bucket < to_next then into_bucket else to_next in
  let margin =
    float_of_int nearest
    *. (pokemon_blink_max_seconds -. pokemon_blink_min_seconds)
    /. fraction_scale
  in
  (* An interval near either end of the range has nowhere to be wrong towards,
     so cap the margin by the distance to the range itself. *)
  let to_longest = longest_seconds -. interval_seconds in
  let to_shortest =
    interval_seconds
    -. (pokemon_blink_min_seconds +. pokemon_blink_offset_seconds)
  in
  Float.max (Float.min margin (Float.min to_longest to_shortest)) 0.0

let pokemon_blink_bucket_with_margin interval_seconds =
  pokemon_blink_fraction interval_seconds
  |> Option.map (fun fraction ->
         let bucket = fraction lsr bucket_shift in
         (bucket, margin_seconds interval_seconds fraction bucket))

type blink_tick = { blinked : bool; blink_type : blink_type }

let generate_blink_ticks state ~ticks ~npcs ~slot =
  if npcs = 0 then
    invalid_arg "generate_blink_ticks: there must be at least one NPC";
  if slot >= npcs then
    invalid_arg "generate_blink_ticks: slot is outside the per-tick order";
  let rng = Xorshift128.create state in
  (* Skip forward to the observed NPC's place. *)
  Xorshift128.advance rng slot;
  List.init ticks (fun _ ->
      let roll = Xorshift128.next rng in
      Xorshift128.advance rng (npcs - 1);
      { blinked = npc_blinks roll; blink_type = npc_blink_type roll })
