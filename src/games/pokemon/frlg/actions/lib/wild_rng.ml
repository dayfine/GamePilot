type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
  shiny_at : int -> bool;
  log : string -> unit;
}

type end_ = Shiny | Not_shiny | Capture_ended of Capture.end_ | Party_full
type result = { end_ : end_; capture : Capture.result option }

let run game_steps (plan : Capture_plan.t) ~party =
  if party >= Capture.party_size then { end_ = Party_full; capture = None }
  else
    let r = game_steps.catch plan ~party in
    match r.end_ with
    | All_caught ->
        let end_ =
          if game_steps.shiny_at (party + 1) then Shiny else Not_shiny
        in
        { end_; capture = Some r }
    | e -> { end_ = Capture_ended e; capture = Some r }

let failure_code = function
  | Shiny -> None
  | Not_shiny -> Some "wild_rng_not_shiny"
  | Capture_ended e -> Some ("wild_rng_" ^ Capture.end_name e)
  | Party_full -> Some "wild_rng_party_full"

let message r =
  match r.end_ with
  | Shiny -> "Wild RNG: the catch is shiny."
  | Not_shiny -> "Wild RNG: the catch is not shiny: the RNG missed its target."
  | Capture_ended e -> "Wild RNG: the capture ended " ^ Capture.end_name e ^ "."
  | Party_full ->
      "Wild RNG: the party is full; the catch's summary needs a slot."
