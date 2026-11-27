type phase = Before_battle | Wild_appearance | Intro_complete
type verdict = Shiny | Not_shiny | Unknown

type thresholds = {
  shiny_delay_ms : float;
  min_margin_ms : float;
  max_margin_ms : float;
}

type reading = {
  verdict : verdict;
  wild_intro_ms : float option;
  phase : phase;
}

type state = {
  phase : phase;
  wild_start_ms : float option;
  wild_intro_ms : float option;
  finished : bool;
}

let default_thresholds =
  { shiny_delay_ms = 2800.; min_margin_ms = 500.; max_margin_ms = 900. }

let probes = Battle_screen.probes @ Battle_text_arrow.probes

let init =
  {
    phase = Before_battle;
    wild_start_ms = None;
    wild_intro_ms = None;
    finished = false;
  }

let is_finished s = s.finished

let gap_since ~t_ms s =
  match s.wild_start_ms with
  | Some start_ms when t_ms >= start_ms -> Some (t_ms -. start_ms)
  | _ -> None

let step_before ~t_ms ~intro_ended ~wild_started s =
  if intro_ended then { s with phase = Intro_complete; finished = true }
  else if wild_started then
    { s with phase = Wild_appearance; wild_start_ms = Some t_ms }
  else s

let step_wild ~t_ms ~intro_ended s =
  if not intro_ended then s
  else
    {
      s with
      phase = Intro_complete;
      wild_intro_ms = gap_since ~t_ms s;
      finished = true;
    }

let step_signals ~t_ms ~battle_text ~foe_box ~advance_arrow ~player_box
    ~battle_menu s =
  if s.finished then s
  else
    let intro_ended = advance_arrow || player_box || battle_menu in
    match s.phase with
    | Before_battle ->
        step_before ~t_ms ~intro_ended ~wild_started:(battle_text || foe_box) s
    | Wild_appearance -> step_wild ~t_ms ~intro_ended s
    | Intro_complete -> s

let step ~(frame : Effects.measurements) s =
  step_signals ~t_ms:frame.t_ms
    ~battle_text:(Battle_screen.battle_text_box frame)
    ~foe_box:(Battle_screen.foe_box frame)
    ~advance_arrow:(Battle_text_arrow.advance_arrow frame)
    ~player_box:(Battle_screen.player_box frame)
    ~battle_menu:(Battle_screen.battle_menu frame)
    s

let classify ?(thresholds = default_thresholds) s =
  let verdict =
    if not s.finished then Unknown
    else
      match s.wild_intro_ms with
      | None -> Unknown
      | Some ms ->
          let lo = thresholds.shiny_delay_ms -. thresholds.min_margin_ms in
          let hi = thresholds.shiny_delay_ms +. thresholds.max_margin_ms in
          if ms >= lo && ms <= hi then Shiny else Not_shiny
  in
  { verdict; wild_intro_ms = s.wild_intro_ms; phase = s.phase }

let verdict_to_string = function
  | Shiny -> "shiny"
  | Not_shiny -> "not_shiny"
  | Unknown -> "unknown"

let format_ms = function
  | None -> "none"
  | Some ms -> Printf.sprintf "%.0fms" ms

let format_reading r =
  Printf.sprintf "verdict=%s wild_intro=%s"
    (verdict_to_string r.verdict)
    (format_ms r.wild_intro_ms)
