type phase = Before_anything | Wild_animation | Your_animation | Post_entry
type verdict = Shiny | Not_shiny | Unknown

type thresholds = {
  shiny_delay_ms : float;
  min_margin_ms : float;
  max_margin_ms : float;
}

type reading = {
  verdict : verdict;
  wild_animation_ms : float option;
  your_animation_ms : float option;
  phase : phase;
}

type state = {
  phase : phase;
  dialog_on : bool;
  dialog_end_ms : float option;
  wild_animation_ms : float option;
  your_animation_ms : float option;
  finished : bool;
}

let default_thresholds =
  { shiny_delay_ms = 3900.; min_margin_ms = 300.; max_margin_ms = 500. }

let probes ~picture =
  Battle_detector.probes ~picture @ Battle_dialog_detector.probes ~picture

let init =
  {
    phase = Before_anything;
    dialog_on = false;
    dialog_end_ms = None;
    wild_animation_ms = None;
    your_animation_ms = None;
    finished = false;
  }

let is_finished s = s.finished

let gap_since ~t_ms s =
  match s.dialog_end_ms with
  | Some start_ms when t_ms >= start_ms -> Some (t_ms -. start_ms)
  | _ -> None

let push_end ~t_ms s =
  let gap = if s.dialog_on then None else gap_since ~t_ms s in
  let wild_animation_ms =
    match (s.phase, s.wild_animation_ms) with
    | Wild_animation, None -> gap
    | _, existing -> existing
  in
  let your_animation_ms =
    match (s.phase, s.your_animation_ms) with
    | Your_animation, None -> gap
    | _, existing -> existing
  in
  { s with wild_animation_ms; your_animation_ms; finished = true }

let on_dialog_appeared ~t_ms s =
  let gap = gap_since ~t_ms s in
  match s.phase with
  | Before_anything -> { s with dialog_on = true; phase = Wild_animation }
  | Wild_animation ->
      {
        s with
        dialog_on = true;
        phase = Your_animation;
        wild_animation_ms = gap;
      }
  | Your_animation ->
      { s with dialog_on = true; phase = Post_entry; your_animation_ms = gap }
  | Post_entry -> { s with dialog_on = true }

let step_signals ~t_ms ~battle_menu ~dialog_on s =
  if s.finished then s
  else if battle_menu then push_end ~t_ms s
  else if dialog_on = s.dialog_on then s
  else if not dialog_on then
    { s with dialog_on = false; dialog_end_ms = Some t_ms }
  else on_dialog_appeared ~t_ms s

let step ~frame s =
  let battle_menu = Battle_detector.shown frame in
  let dialog_on = Battle_dialog_detector.shown frame in
  step_signals ~t_ms:frame.t_ms ~battle_menu ~dialog_on s

let classify ?(thresholds = default_thresholds) s =
  let verdict =
    if not s.finished then Unknown
    else
      match s.wild_animation_ms with
      | None -> Unknown
      | Some ms ->
          let lo = thresholds.shiny_delay_ms -. thresholds.min_margin_ms in
          let hi = thresholds.shiny_delay_ms +. thresholds.max_margin_ms in
          if ms >= lo && ms <= hi then Shiny else Not_shiny
  in
  {
    verdict;
    wild_animation_ms = s.wild_animation_ms;
    your_animation_ms = s.your_animation_ms;
    phase = s.phase;
  }

let verdict_to_string = function
  | Shiny -> "shiny"
  | Not_shiny -> "not_shiny"
  | Unknown -> "unknown"

let format_ms = function
  | None -> "none"
  | Some ms -> Printf.sprintf "%.0fms" ms

let format_reading r =
  Printf.sprintf "verdict=%s wild=%s your=%s"
    (verdict_to_string r.verdict)
    (format_ms r.wild_animation_ms)
    (format_ms r.your_animation_ms)
