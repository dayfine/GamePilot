type t = {
  fade : Fade.t;
  banner : bool;
  arrived : bool;
  dialog : bool;
  battle : bool;
  free_control : bool;
  screen_still : bool;
  player_still : bool;
}

let none =
  {
    fade = Fade.No_fade;
    banner = false;
    arrived = false;
    dialog = false;
    battle = false;
    free_control = false;
    screen_still = false;
    player_still = false;
  }

let shows_warp t = t.fade <> Fade.No_fade || t.banner || t.arrived
