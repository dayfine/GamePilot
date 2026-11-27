type action_t = { hold_ms : int; cooldown_ms : int; radar_cooldown_ms : int }

type door_t = {
  default_hold_ms : int;
  step_ms : int;
  retry_hold_ms : int;
  nudge_step_ms : int;
  fade_timeout_ms : int;
  black_hold_ms : float;
  clear_hold_ms : float;
}

type menu_t = {
  press_hold_ms : int;
  press_cooldown_ms : int;
  nav_hold_ms : int;
  nav_cooldown_ms : int;
  wait_timeout_ms : int;
  post_wait_ms : int;
}

type dialog_t = {
  max_presses : int;
  press_cooldown_ms : int;
  frame_timeout_ms : int;
  bag_open_wait_ms : int;
  kit_confirm_wait_ms : int;
  dive_timeout_ms : int;
  battle_timeout_ms : int;
  battle_run_wait_ms : int;
}

type bag_t = {
  scroll_pages : int;
  page_rows : int;
  nav_hold_ms : int;
  nav_cooldown_ms : int;
  page_wait_ms : int;
  exit_presses : int;
  exit_cooldown_ms : int;
}

let act = { hold_ms = 100; cooldown_ms = 250; radar_cooldown_ms = 1200 }

let door =
  {
    default_hold_ms = 900;
    step_ms = 350;
    retry_hold_ms = 1050;
    nudge_step_ms = 350;
    fade_timeout_ms = 8000;
    black_hold_ms = 80.;
    clear_hold_ms = 200.;
  }

let menu =
  {
    press_hold_ms = 160;
    press_cooldown_ms = 840;
    nav_hold_ms = 120;
    nav_cooldown_ms = 220;
    wait_timeout_ms = 10_000;
    post_wait_ms = 100;
  }

let dlg =
  {
    max_presses = 8;
    press_cooldown_ms = 500;
    frame_timeout_ms = 1000;
    bag_open_wait_ms = 900;
    kit_confirm_wait_ms = 1200;
    dive_timeout_ms = 25_000;
    battle_timeout_ms = 20_000;
    battle_run_wait_ms = 5000;
  }

let bag =
  {
    scroll_pages = 5;
    page_rows = 6;
    nav_hold_ms = 80;
    nav_cooldown_ms = 140;
    page_wait_ms = 1200;
    exit_presses = 4;
    exit_cooldown_ms = 700;
  }
