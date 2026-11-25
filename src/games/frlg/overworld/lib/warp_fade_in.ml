let step_min = 10.
let still_tolerance = 4.
let still_ms = 200.
let unchanged_ms = 1000.

type t = {
  first : float;  (** the first lit frame's brightness *)
  first_ms : float;
  mutable changed : bool;
  mutable still_level : float;  (** brightness where the still spell began *)
  mutable still_from_ms : float;
}

let brightness m =
  Option.map
    (fun (s : Frlg_readers.Solid_color.stats) ->
      Frlg_readers.Solid_color.sum s.mean)
    (Frlg_readers.Solid_color.read m Frlg_readers.Screen_facts.fade_id)

let create (m : Effects.measurements) =
  let first = Option.value (brightness m) ~default:0. in
  {
    first;
    first_ms = m.t_ms;
    changed = false;
    still_level = first;
    still_from_ms = m.t_ms;
  }

let see t ~at_ms ~now =
  if Float.abs (now -. t.first) >= step_min then t.changed <- true;
  if Float.abs (now -. t.still_level) > still_tolerance then (
    t.still_level <- now;
    t.still_from_ms <- at_ms);
  if t.changed then at_ms -. t.still_from_ms >= still_ms
  else at_ms -. t.first_ms >= unchanged_ms

let seen t (m : Effects.measurements) =
  match brightness m with None -> false | Some now -> see t ~at_ms:m.t_ms ~now

type phase = Up | Down | Coming_up of t
type watch = { mutable phase : phase }

let watch () = { phase = Up }

let faded m =
  (Frlg_readers.Screen_facts.of_measurements m).fade
  <> Screen_state.Fade.No_fade

let watch_frame w (m : Effects.measurements) =
  match w.phase with
  | _ when faded m -> w.phase <- Down
  | Down -> w.phase <- Coming_up (create m)
  | Coming_up t -> if seen t m then w.phase <- Up
  | Up -> ()

let fading w = w.phase <> Up
