(* Port of AdvRngState and its constructors (Pokemon/Pokemon_AdvRng.{h,cpp}). *)

type rng_method = Method1 | Method2 | Method3 | Method4 | Any

type t = {
  seed : int;
  advance : int;
  rng_method : rng_method;
  s0 : int;
  s1 : int;
  s2 : int;
  s3 : int;
  s4 : int;
  s5 : int;
}

let of_internal_state ~seed ~advance rng_method s0 =
  let s1 = Lcg.next s0 in
  let s2 = Lcg.next s1 in
  let s3 = Lcg.next s2 in
  let s4 = Lcg.next s3 in
  let s5 = Lcg.next s4 in
  { seed; advance; rng_method; s0; s1; s2; s3; s4; s5 }

let of_seed ~seed ~advance rng_method =
  of_internal_state ~seed ~advance rng_method (Lcg.jump seed (advance + 1))

let next t =
  {
    t with
    advance = t.advance + 1;
    s0 = t.s1;
    s1 = t.s2;
    s2 = t.s3;
    s3 = t.s4;
    s4 = t.s5;
    s5 = Lcg.next t.s5;
  }
