type t = {
  encounter_per_tile : float;
  encounter_ms : int;
  wanderer_per_tile : float;
  wanderer_ms : int;
  trainer_ms : int;
  replan_ms : int;
  max_recoveries : int;
  max_spread : int;
}

let none =
  {
    encounter_per_tile = 0.;
    encounter_ms = 0;
    wanderer_per_tile = 0.;
    wanderer_ms = 0;
    trainer_ms = 0;
    replan_ms = 0;
    max_recoveries = 3;
    max_spread = 32;
  }
