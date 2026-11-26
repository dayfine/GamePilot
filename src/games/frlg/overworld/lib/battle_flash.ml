let window_ms = 400.

(* The dip is below this share of the brightest frame before it (the fork's is
   0.8), above this share (lower is a fade to black), and the screen then comes
   back to this much of the dip (the fork's). *)
let darker = 0.88
let floor_share = 0.4
let recovery = 1.1

type t = { mutable history : (float * float) list  (** oldest first *) }

let create () = { history = [] }

(* The brightest frame before the screen first dips, and the darkest since;
   [None] for no dip. *)
let dip_after_bright history =
  let step (before, dip) (_, b) =
    match dip with
    | None ->
        if b < before *. darker then (before, Some b) else (max before b, None)
    | Some d -> (before, Some (min d b))
  in
  match List.fold_left step (0., None) history with
  | before, Some dip -> Some (before, dip)
  | _, None -> None

let brightness m =
  Option.map
    (fun (s : Frlg_readers.Solid_color.stats) ->
      Frlg_readers.Solid_color.sum s.mean)
    (Frlg_readers.Solid_color.read m Frlg_readers.Screen_facts.fade_id)

let flash_ends ~recent ~now =
  match dip_after_bright recent with
  | Some (before, dip) -> dip > before *. floor_share && now > dip *. recovery
  | None -> false

type sign = Flash | Going_black

(* The frame is below [floor_share] of the brightest one before it. *)
let going_black ~recent ~now =
  let brightest = List.fold_left (fun b (_, x) -> max b x) 0. recent in
  now < brightest *. floor_share

let see t ~at_ms ~now =
  let recent =
    List.filter (fun (at, _) -> at_ms -. at <= window_ms) t.history
  in
  let fired = flash_ends ~recent ~now in
  (* A flash fires once: the frames after it start a new history. *)
  t.history <- (if fired then [] else recent @ [ (at_ms, now) ]);
  if fired then Some Flash
  else if going_black ~recent ~now then Some Going_black
  else None

let sign t (m : Effects.measurements) =
  match brightness m with None -> None | Some now -> see t ~at_ms:m.t_ms ~now

let seen t m = sign t m = Some Flash
