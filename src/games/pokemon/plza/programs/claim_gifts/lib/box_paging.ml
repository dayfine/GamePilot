module T = Switch_home.Timed_press
module Title = Plza_readers.Box_title

type t = { box_one : Title.t; opened : Title.t; ls : int }

let page button : T.t = { button; hold_ms = 80; cooldown_ms = 800 }
let hold_ms = 1000.
let title_ms = 3000
let max_ls = 40

(* The title, the same for [hold_ms] on the Boxes. *)
let steady () =
  let first = ref None in
  fun (m : Effects.measurements) ->
    let read =
      if Plza_readers.Boxes_screen.shown m then Title.read m else None
    in
    match (read, !first) with
    | None, _ ->
        first := None;
        None
    | Some t, Some (t0, since) when Title.same t t0 ->
        if m.t_ms -. since >= hold_ms then Some t else None
    | Some t, _ ->
        first := Some (t, m.t_ms);
        None

let title () = Switch_home.Held_screen.wait_for ~timeout_ms:title_ms (steady ())

let titled what =
  match title () with Some t -> Ok t | None -> Error ("no box title " ^ what)

let ( let* ) = Result.bind

(* Box 1 reached, [ls] Ls below the open box, after the L to the last box and
   R back. *)
let came_back ~log ~box_one ~opened ~ls =
  T.press (page R);
  let* back = titled "after R back from the last box" in
  if Title.same back box_one then (
    log (Printf.sprintf "Box 1, %d L from the open box (Box %d)." ls (ls + 1));
    Ok { box_one = back; opened; ls })
  else Error "R from the last box did not come back to Box 1's title"

let to_box_one ~log =
  let* opened = titled "on the Boxes" in
  let rec down ls before =
    if ls > max_ls then
      Error (Printf.sprintf "no box title widened in %d L" max_ls)
    else (
      T.press (page L);
      let* after = titled "after L" in
      if Title.one_more_digit ~before ~after then
        came_back ~log ~box_one:before ~opened ~ls
      else down (ls + 1) after)
  in
  down 0 opened

let opened_on t = t.ls + 1

let paged t button ~expect what =
  T.press_all (T.times t.ls (page button));
  let* now = titled ("on " ^ what) in
  if Title.same now expect then Ok ()
  else
    Error
      (Printf.sprintf "the title after %d %s is not %s's" t.ls
         (Wire.string_of_button button)
         what)

let to_opened t =
  paged t R ~expect:t.opened (Printf.sprintf "Box %d" (opened_on t))

let back_to_box_one t = paged t L ~expect:t.box_one "Box 1"
